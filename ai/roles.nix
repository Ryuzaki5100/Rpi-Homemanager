# Role definitions shared by OpenCode and Claude Code.
#
# One record per role: the prose body (roles/<name>.md) is used verbatim by
# both tools, while the `opencode` and `claude` attrsets carry the per-tool
# model, effort and policy. ai/lib.nix renders the two agent files.
#
#   pro-dev         planner + orchestrator, never edits code
#   pro-worker      implementation worker (one instance class)
#   pro-worker-lite the same worker on a cheap model, for chores and easy fixes
#
# Both workers exist so the orchestrator can pick a model per task without
# inventing a new role; at most two of them may run at once.
let
  # Home Manager wires MCP servers through a generated plugin named "hm", so
  # Claude Code scopes their tools as mcp__plugin_hm_<server>__<tool>. The
  # unscoped form is included as well so the allowlist keeps working if the
  # servers are ever configured directly instead of through that plugin.
  mcpTools = server: "mcp__plugin_hm_${server}__*, mcp__${server}__*";
in
{
  pro-dev = {
    description = "Planner and orchestrator. Turns a request into a vault plan, files the GitHub issue, and dispatches at most two workers on disjoint files. Never edits code itself.";
    body = ./roles/pro-dev.md;
    opencode = {
      mode = "primary";
      model = "opencode-go/deepseek-v4-pro#high";
      color = "#d4b483";
      permissions = [
        {
          action = "subagent";
          resource = "*";
          effect = "deny";
        }
        {
          action = "subagent";
          resource = "pro-worker";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "pro-worker-lite";
          effect = "allow";
        }
        {
          action = "subagent";
          resource = "pro-worker-deep";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "**";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "ask";
        }
        {
          action = "shell";
          resource = "prodev *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "gh *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git status*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git log*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git diff*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git merge*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "rg *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "ls *";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "find *";
          effect = "allow";
        }
      ];
    };
    claude = {
      model = "opus";
      effort = "high";
      tools = "Agent(pro-worker, pro-worker-lite, pro-worker-deep), Read, Grep, Glob, Bash, TodoWrite, WebFetch, WebSearch, ${mcpTools "roblox"}, ${mcpTools "firecrawl"}";
      disallowedTools = "Write, Edit, NotebookEdit";
      maxTurns = 60;
    };
  };

  pro-worker = {
    description = "Implements exactly one vault task in an isolated worktree, runs the project checks, and reports. Never touches another task's files.";
    body = ./roles/pro-worker.md;
    opencode = {
      mode = "subagent";
      model = "opencode-go/deepseek-v4.1-flash#medium";
      color = "#8fb3a8";
      permissions = [
        {
          action = "edit";
          resource = "**";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "**/.prodev-vault/**";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git push*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "git reset --hard*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "git clean -fdx*";
          effect = "deny";
        }
      ];
    };
    claude = {
      model = "sonnet";
      effort = "medium";
      tools = "Read, Write, Edit, Bash, Grep, Glob, TodoWrite, ${mcpTools "roblox"}, ${mcpTools "firecrawl"}";
      isolation = "worktree";
      maxTurns = 80;
    };
  };

  pro-worker-deep = {
    description = "Escalation worker: the same contract as pro-worker at high effort, for genuinely hard work (concurrency, performance, tricky debugging). Not for routine tasks.";
    body = ./roles/pro-worker.md;
    opencode = {
      mode = "subagent";
      model = "opencode-go/deepseek-v4.1-flash#high";
      color = "#6f93a8";
      permissions = [
        {
          action = "edit";
          resource = "**";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "**/.prodev-vault/**";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git push*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "git reset --hard*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "git clean -fdx*";
          effect = "deny";
        }
      ];
    };
    claude = {
      model = "sonnet";
      effort = "high";
      tools = "Read, Write, Edit, Bash, Grep, Glob, TodoWrite, ${mcpTools "roblox"}, ${mcpTools "firecrawl"}";
      isolation = "worktree";
      maxTurns = 80;
    };
  };

  pro-worker-lite = {
    description = "The same worker on a cheap model: GitHub chores, commits, lint/format, docs, dependency bumps, and trivial fixes.";
    body = ./roles/pro-worker.md;
    opencode = {
      mode = "subagent";
      model = "opencode-go/deepseek-v4.1-flash#low";
      color = "#a89f8f";
      permissions = [
        {
          action = "edit";
          resource = "**";
          effect = "allow";
        }
        {
          action = "edit";
          resource = "**/.prodev-vault/**";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "*";
          effect = "allow";
        }
        {
          action = "shell";
          resource = "git push*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "git reset --hard*";
          effect = "deny";
        }
        {
          action = "shell";
          resource = "git clean -fdx*";
          effect = "deny";
        }
      ];
    };
    claude = {
      model = "haiku";
      effort = "medium";
      tools = "Read, Write, Edit, Bash, Grep, Glob, TodoWrite, ${mcpTools "roblox"}, ${mcpTools "firecrawl"}";
      maxTurns = 60;
    };
  };
}
