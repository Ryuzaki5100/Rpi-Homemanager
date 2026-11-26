# Renderers that turn one role definition into an OpenCode agent file and a
# Claude Code agent file. The role body (ai/roles/*.md) is shared verbatim; only
# the frontmatter differs, because the two tools describe the same ideas with
# different field names.
{ lib }:

let
  # YAML single-quoted scalar. Newlines are folded to spaces because every
  # description is a one-liner by contract.
  yamlStr =
    s:
    "'"
    + lib.replaceStrings [ "'" "\n" ] [ "''" " " ] s
    + "'";

  emitPermissions =
    perms: lib.concatMap (p: [
      "- action: ${p.action}"
      "  resource: ${yamlStr p.resource}"
      "  effect: ${p.effect}"
    ]) perms;

  # `key: value` lines, skipping every field the role does not set, so the
  # frontmatter stays valid YAML with no indented root keys.
  optional =
    role: key: field: fmt:
    lib.optional (builtins.hasAttr field role.claude) "${key}: ${fmt role.claude.${field}}";

  claudeFrontmatter =
    name: role:
    [
      "---"
      "name: ${name}"
      "description: ${yamlStr role.description}"
      "model: ${role.claude.model}"
      "effort: ${role.claude.effort}"
      "tools: ${role.claude.tools}"
    ]
    ++ optional role "disallowedTools" "disallowedTools" toString
    ++ optional role "permissionMode" "permissionMode" toString
    ++ optional role "isolation" "isolation" toString
    ++ optional role "maxTurns" "maxTurns" toString
    ++ [ "---" ];

in
{
  # OpenCode v2 agent: `permissions` is an ordered list of rules, and the model
  # carries its variant as a `#variant` suffix.
  opencodeAgent =
    role:
    lib.concatStringsSep "\n" (
      [
        "---"
        "description: ${yamlStr role.description}"
        "mode: ${role.opencode.mode}"
        "model: ${role.opencode.model}"
        "color: ${yamlStr role.opencode.color}"
        "permissions:"
      ]
      ++ emitPermissions role.opencode.permissions
      ++ [
        "---"
        ""
        (lib.readFile role.body)
      ]
    );

  # Claude Code agent: frontmatter fields are camelCase, `tools` is an
  # allowlist, and `Agent(a, b)` restricts which subagents the main-thread
  # agent may spawn.
  claudeAgent =
    name: role:
    lib.concatStringsSep "\n" (claudeFrontmatter name role ++ [ "" (lib.readFile role.body) ]);
}
