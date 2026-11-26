# One MCP definition per server, rendered into the shape each tool expects.
#
# OpenCode uses `mcp.servers.<name>` with `type = "local"`, a full argv, an
# `environment` map and its own extras (`codemode`, object-shaped `timeout`).
# Claude Code uses `.mcp.json` with `type = "stdio"`, `command` + `args` and
# `env`. Servers that are genuinely portable are defined once here and derived
# for both; anything tool-specific stays inside the matching branch.
{ pkgs, home, isDarwin }:

let
  apiKeyFile = "${home}/.config/firecrawl/api-key";
  gmailCredentials = "${home}/.config/gmail-mcp/credentials.json";
  gmailToken = "${home}/.config/gmail-mcp/token.json";

  # OpenCode understands the `{file:…}` substitution token. Claude Code does
  # not, so it gets a wrapper that reads the key at process start instead of
  # passing the literal token as the secret.
  firecrawlClaude = pkgs.writeShellScriptBin "firecrawl-mcp-claude" ''
    if [ -r "${apiKeyFile}" ]; then
      FIRECRAWL_API_KEY=$(cat "${apiKeyFile}")
      export FIRECRAWL_API_KEY
    fi
    exec ${pkgs.nodejs}/bin/npx -y firecrawl-mcp@3.23.8 "$@"
  '';

in
{
  gmail = {
    opencode = {
      type = "local";
      command = [
        "uv"
        "run"
        "--no-project"
        "--with"
        "mcp-google-gmail"
        "--with"
        "mcp>=1.8.0,<2"
        "mcp-google-gmail"
      ];
      environment = {
        GMAIL_CREDENTIALS_PATH = gmailCredentials;
        GMAIL_TOKEN_PATH = gmailToken;
      };
    };
    claude = {
      type = "stdio";
      command = "uv";
      args = [
        "run"
        "--no-project"
        "--with"
        "mcp-google-gmail"
        "--with"
        "mcp>=1.8.0,<2"
        "mcp-google-gmail"
      ];
      env = {
        GMAIL_CREDENTIALS_PATH = gmailCredentials;
        GMAIL_TOKEN_PATH = gmailToken;
      };
    };
  };

  firecrawl = {
    opencode = {
      type = "local";
      command = [
        "npx"
        "-y"
        "firecrawl-mcp@3.23.8"
      ];
      environment.FIRECRAWL_API_KEY = "{file:${apiKeyFile}}";
    };
    claude = {
      type = "stdio";
      command = "${firecrawlClaude}/bin/firecrawl-mcp-claude";
      args = [ ];
    };
  };
}
// (
  if isDarwin then
    {
      # Roblox Studio's MCP server lives inside the .app; `roblox-studio-mcp`
      # (modules/darwin/roblox.nix) is the stable wrapper around it.
      roblox = {
        opencode = {
          type = "local";
          command = [ "roblox-studio-mcp" ];
          codemode = true;
          # Studio enumerates ~25 tools on startup and playtest jobs run for
          # minutes; the 5s default is too tight on both ends.
          timeout = {
            startup = 60000;
            catalog = 120000;
            execution = 300000;
          };
        };
        claude = {
          type = "stdio";
          command = "roblox-studio-mcp";
          args = [ ];
        };
      };
    }
  else
    { }
)
