"""Launch opencode against LM Studio's headless local server.

Only models that are (a) present and complete on disk and (b) able to run on
this machine at their advertised context are exposed to the opencode TUI.

The LM Studio server is started on demand, and any model it JIT-loads during
the session is unloaded again once opencode exits.
"""

import argparse
import concurrent.futures
import json
import os
import re
import signal
import subprocess
import sys
import time
import urllib.request

GIB = 1 << 30
MIB = 1 << 20
DEFAULT_PORT = 1234
LMS = os.path.expanduser("~/.lmstudio/bin/lms")
MODELS_DIR = os.path.expanduser("~/.lmstudio/models")

CONTEXT_CANDIDATES = [1 << i for i in range(13, 19)]  # 8192 .. 262144


def log(args, message):
    if args.verbose:
        print(f"opl: {message}", file=sys.stderr)


def die(message):
    print(f"opl: {message}", file=sys.stderr)
    sys.exit(1)


def find_lms():
    if os.path.isfile(LMS) and os.access(LMS, os.X_OK):
        return LMS
    from shutil import which

    found = which("lms")
    if found:
        return found
    die("LM Studio CLI not found (expected ~/.lmstudio/bin/lms)")
    return None


def run(cmd, timeout=60, check=False):
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if check and proc.returncode != 0:
        detail = proc.stderr.strip()
        raise RuntimeError(
            f"{' '.join(cmd)} failed ({proc.returncode}): {detail}"
        )
    return proc


def server_status(lms):
    try:
        proc = run([lms, "server", "status", "--json"], timeout=20)
        if proc.returncode != 0:
            return None
        return json.loads(proc.stdout)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def server_running(status):
    if not status:
        return False
    return bool(status.get("running") or status.get("status") == "running")


def ensure_server(lms, args):
    status = server_status(lms)
    if server_running(status):
        return int(status.get("port") or DEFAULT_PORT)

    if args.no_server or args.print_config:
        return DEFAULT_PORT

    log(args, "starting LM Studio server")
    try:
        run([lms, "server", "start"], timeout=120)
    except subprocess.TimeoutExpired:
        pass

    for _ in range(120):
        status = server_status(lms)
        if server_running(status):
            port = int(status.get("port") or DEFAULT_PORT)
            log(args, f"server running on port {port}")
            return port
        time.sleep(0.25)

    die("LM Studio server did not start")


def api_models(base_url):
    url = base_url.rstrip("/") + "/api/v1/models"
    with urllib.request.urlopen(url, timeout=3) as response:
        return json.load(response)


def ps_fallback(lms):
    try:
        proc = run([lms, "ps", "--json"], timeout=20)
        return json.loads(proc.stdout)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return []


def ps_identifiers(lms):
    identifiers = set()
    for entry in ps_fallback(lms) or []:
        if isinstance(entry, str):
            identifiers.add(entry)
            continue
        if not isinstance(entry, dict):
            continue
        identifier = (
            entry.get("identifier")
            or entry.get("modelKey")
            or entry.get("id")
        )
        if identifier:
            identifiers.add(identifier)
    return identifiers


def loaded_instances(base_url, lms, sizes):
    """Return (instance ids, bytes currently loaded).

    The REST API only reports models held by the server it belongs to, so the
    `lms ps` list is unioned in as well; sizes come from the on-disk inventory.
    """
    ids = set()
    size_map = dict(sizes)

    try:
        for model in api_models(base_url).get("models", []):
            for instance in model.get("loaded_instances") or []:
                ids.add(instance.get("id") or model.get("key"))
                size_map.setdefault(
                    model.get("key"), int(model.get("size_bytes") or 0)
                )
    except Exception:
        pass

    ids |= ps_identifiers(lms)
    total = sum(size_map.get(identifier, 0) for identifier in ids)
    return ids, total


def estimate(lms, key, context):
    proc = run(
        [lms, "load", key, "--estimate-only", "-y", "-c", str(context)],
        timeout=120,
    )
    if proc.returncode != 0:
        return None

    output = proc.stdout + proc.stderr
    match = re.search(
        r"Estimated Total Memory:\s*([\d.]+)\s*(GiB|MiB|GB|MB)", output
    )
    if not match:
        return None

    value = float(match.group(1))
    unit = match.group(2)
    multiplier = {
        "GiB": GIB,
        "MiB": MIB,
        "GB": 1_000_000_000,
        "MB": 1_000_000,
    }[unit]

    verdict = "unknown"
    if "will fail to load" in output:
        verdict = "fail"
    elif "may be loaded" in output:
        verdict = "ok"

    return {"bytes": int(value * multiplier), "verdict": verdict}


def kv_bytes_per_token(model):
    """Estimate KV-cache bytes per token from an MLX model's config.json."""
    path = os.path.join(MODELS_DIR, str(model.get("path") or ""))
    config_path = os.path.join(path, "config.json")
    if not os.path.isfile(config_path):
        return None

    try:
        with open(config_path, encoding="utf-8") as handle:
            config = json.load(handle)
    except (OSError, ValueError):
        return None

    text = config.get("text_config") or config
    hidden = text.get("num_hidden_layers")
    heads = text.get("num_attention_heads")
    kv_heads = text.get("num_key_value_heads") or heads
    head_dim = text.get("head_dim")
    if not head_dim and heads and text.get("hidden_size"):
        head_dim = text["hidden_size"] // heads

    if not hidden or not kv_heads or not head_dim:
        return None

    layer_types = text.get("layer_types")
    if layer_types:
        full_layers = sum(
            1 for item in layer_types if item == "full_attention"
        )
    else:
        full_layers = hidden

    dtype = str(text.get("dtype") or text.get("torch_dtype") or "bfloat16")
    bytes_per_element = 4 if "float32" in dtype or dtype.endswith("32") else 2

    return 2 * full_layers * kv_heads * head_dim * bytes_per_element


def pick_context(model, lms, budget, args):
    """Return the advertised context for a model, or None if it cannot run."""
    max_context = min(
        int(model.get("maxContextLength") or CONTEXT_CANDIDATES[0]),
        args.max_context,
    )
    candidates = [
        value for value in CONTEXT_CANDIDATES if value <= max_context
    ]
    if not candidates:
        candidates = [max_context]

    base = estimate(lms, model["modelKey"], 2048)
    if base is None:
        log(args, f"{model['modelKey']}: not loadable (estimate failed)")
        return None

    top = estimate(lms, model["modelKey"], candidates[-1])
    flat = top is not None and abs(top["bytes"] - base["bytes"]) <= MIB

    if flat:
        if base["bytes"] > budget:
            log(args, f"{model['modelKey']}: weights exceed RAM budget")
            return None

        kv_per_token = kv_bytes_per_token(model)
        if kv_per_token:
            headroom = budget - base["bytes"]
            allowed = headroom // kv_per_token
            fitting = [value for value in candidates if value <= allowed]
            chosen = fitting[-1] if fitting else None
        else:
            chosen = min(max_context, 32768)

        if chosen is None:
            log(args, f"{model['modelKey']}: no context fits RAM budget")
            return None
        log(
            args,
            f"{model['modelKey']}: flash/flat estimate, context={chosen}",
        )
        return chosen

    for context in reversed(candidates):
        result = estimate(lms, model["modelKey"], context)
        if result is None or result["verdict"] == "fail":
            continue
        if result["bytes"] > budget:
            continue
        log(
            args,
            f"{model['modelKey']}: context={context} "
            f"estimate={result['bytes'] / GIB:.1f} GiB",
        )
        return context

    log(args, f"{model['modelKey']}: no context fits RAM budget")
    return None


def build_config(selected, port, argv):
    base_api = f"http://127.0.0.1:{port}"
    first = selected[0]["modelKey"]

    models = {}
    for model in selected:
        key = model["modelKey"]
        vision = bool(model.get("vision"))
        modalities = ["text"] + (["image"] if vision else [])
        models[key] = {
            "id": key,
            "name": model.get("displayName") or key,
            "attachment": vision,
            "tool_call": bool(model.get("trainedForToolUse", True)),
            "temperature": True,
            "reasoning": False,
            "cost": {"input": 0, "output": 0},
            "limit": {
                "context": model["context"],
                "output": min(8192, model["context"]),
            },
            "modalities": {"input": modalities, "output": ["text"]},
            "status": "active",
        }

    config = {
        "enabled_providers": ["lmstudio"],
        "model": f"lmstudio/{first}",
        "small_model": f"lmstudio/{first}",
        "provider": {
            "lmstudio": {
                "api": f"{base_api}/v1",
                "name": "LM Studio (local)",
                "npm": "@ai-sdk/openai-compatible",
                "options": {
                    "baseURL": f"{base_api}/v1",
                    "apiKey": "lm-studio",
                },
                "whitelist": list(models),
                "models": models,
            }
        },
    }

    if any(
        arg in ("-m", "--model")
        or arg.startswith("--model=")
        or arg.startswith("-m=")
        for arg in argv
    ):
        config.pop("model", None)
        config.pop("small_model", None)

    return config


def list_inventory(lms):
    proc = run([lms, "ls", "--json", "--llm"], timeout=60)
    if proc.returncode != 0:
        die("failed to list LM Studio models")

    try:
        return json.loads(proc.stdout)
    except ValueError:
        die("could not parse `lms ls --json`")


def select_models(inventory, lms, args, budget):
    def probe(model):
        context = pick_context(model, lms, budget, args)
        if context is None:
            return None
        copy = dict(model)
        copy["context"] = context
        return copy

    available = [
        model
        for model in inventory
        if model.get("type") == "llm" and int(model.get("sizeBytes") or 0) > 0
    ]

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(probe, available))

    selected = [model for model in results if model is not None]
    if not selected:
        die("no on-disk LM Studio model is loadable on this machine")
    return selected


def main():
    parser = argparse.ArgumentParser(
        description="Launch opencode against loadable LM Studio models."
    )
    parser.add_argument(
        "--print-config",
        action="store_true",
        help="print the generated opencode config and exit",
    )
    parser.add_argument(
        "--no-server",
        action="store_true",
        help="do not start the LM Studio server",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="verbose logging"
    )
    parser.add_argument(
        "--ram-fraction",
        type=float,
        default=0.85,
        help="fraction of physical RAM usable by models (default: 0.85)",
    )
    parser.add_argument(
        "--reserve-gib",
        type=float,
        default=2.0,
        help="GiB reserved for opencode and the OS (default: 2)",
    )
    parser.add_argument(
        "--max-context",
        type=int,
        default=262144,
        help="upper bound for advertised context (default: 262144)",
    )
    args, opencode_argv = parser.parse_known_args()
    # argparse leaves the `--` separator in the extras; opencode has its own
    # argument parsing and should only see the real arguments.
    opencode_argv = [arg for arg in opencode_argv if arg != "--"]

    lms = find_lms()

    try:
        memsize = run(["sysctl", "-n", "hw.memsize"], timeout=10)
        total_ram = int(memsize.stdout.strip())
    except (OSError, ValueError, subprocess.TimeoutExpired):
        die("could not read physical memory size")

    port = ensure_server(lms, args)
    base_api = f"http://127.0.0.1:{port}"

    inventory = list_inventory(lms)
    sizes = {
        model["modelKey"]: int(model.get("sizeBytes") or 0)
        for model in inventory
        if model.get("modelKey")
    }

    before_ids, preloaded_bytes = loaded_instances(base_api, lms, sizes)

    budget = int(total_ram * args.ram_fraction) - int(args.reserve_gib * GIB)
    budget -= preloaded_bytes
    if budget <= 0:
        die("no RAM budget left for a local model")

    log(
        args,
        f"budget={budget / GIB:.1f} GiB "
        f"(preloaded={preloaded_bytes / GIB:.1f} GiB)",
    )

    selected = select_models(inventory, lms, args, budget)
    config = build_config(selected, port, opencode_argv)

    if args.print_config:
        print(json.dumps(config, indent=2))
        return 0

    env = os.environ.copy()
    env["OPENCODE_CONFIG_CONTENT"] = json.dumps(config)
    env["LMSTUDIO_API_KEY"] = "lm-studio"

    proc = subprocess.Popen(["opencode", *opencode_argv], env=env)

    def forward(signum, _frame):
        try:
            proc.send_signal(signum)
        except ProcessLookupError:
            pass

    for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, forward)

    returncode = 1
    try:
        returncode = proc.wait()
    finally:
        for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(signum, signal.SIG_DFL)

        after_ids, _ = loaded_instances(base_api, lms, sizes)
        for identifier in sorted(after_ids - before_ids):
            log(args, f"unloading {identifier}")
            try:
                run([lms, "unload", identifier], timeout=60)
            except (OSError, subprocess.TimeoutExpired) as error:
                print(
                    f"opl: failed to unload {identifier}: {error}",
                    file=sys.stderr,
                )

    return returncode


if __name__ == "__main__":
    sys.exit(main())
