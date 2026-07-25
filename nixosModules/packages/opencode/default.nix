{
  lib,
  config,
  self,
  pkgs,
  ...
}:
{
  options.nixos.packages.opencode = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config = lib.mkIf (config.nixos.packages.opencode != null) (
    let
      opencode-wrapped = pkgs.writeShellScriptBin "opencode" ''
        export HINDSIGHT_API_TOKEN=$(cat ${config.nixos.system.sops.secrets."hindsight/password".path})
        export HINDSIGHT_API_URL=https://hindsight.chn.moe
        export OPENALEX_MAILTO=chn@chn.moe
        export MINERU_API_KEY=$(cat ${config.nixos.system.sops.secrets."opencode/mineru".path})
        exec ${lib.getExe self.inputs.llm-agents.packages.x86_64-linux.opencode} "$@"
      '';
    in
    {
      environment = {
        systemPackages = [
          opencode-wrapped
          # needed by opencode-notifier
          pkgs.libnotify
          self.inputs.llm-agents.packages.x86_64-linux.agent-browser
          self.inputs.camoufox-nix.packages.x86_64-linux.camofox-browser
        ];
        persistence."/nix/persistent".users.chn.directories = [ ".cache/opencode" ];
      };
      nixos.system.sops.secrets = {
        "github/token".mode = "0444";
        "opencode/mineru".mode = "0444";
        "hindsight/password".mode = "0444";
      };
      nixos.user.sharedModules = [
        {
          config = {
            programs.opencode = {
              enable = true;
              package = opencode-wrapped;
              enableMcpIntegration = true;
              tui.keybinds = {
                input_submit = "ctrl+return";
                input_newline = "return";
              };
              settings = {
                model = "antigravity-gemini-3.1-pro";
                small_model = "antigravity-gemini-3-flash";
                provider.google = {
                  options = {
                    baseURL = "http://localhost:8999/v1";
                    apiKey = "sk-mock";
                  };
                  # copy from https://github.com/NoeFabris/opencode-antigravity-auth#models
                  models = (builtins.fromJSON (builtins.readFile ./google.json)).provider.google.models;
                };
                plugin = [
                  "@mohak34/opencode-notifier@0.2.8"
                  "@vectorize-io/opencode-hindsight"
                ];
                autoupdate = false;
                mcp = {
                  dockerhub = {
                    type = "local";
                    command = [ (lib.getExe pkgs.localPkgs.dockerhub-mcp) ];
                  };
                  openalex = {
                    type = "local";
                    command = [ (lib.getExe pkgs.python3Packages.alex-mcp) ];
                  };
                  mineru = {
                    type = "local";
                    command = [ (lib.getExe pkgs.python3Packages.mineru-mcp) ];
                  };
                  camoufox = {
                    type = "local";
                    command = [
                      (lib.getExe self.inputs.camoufox-nix.packages.x86_64-linux.camofox-mcp)
                    ];
                  };
                  nixos = {
                    type = "local";
                    command = [ (lib.getExe pkgs.mcp-nixos) ];
                  };
                  github = {
                    type = "remote";
                    url = "https://api.githubcopilot.com/mcp/";
                    oauth = false;
                    headers.Authorization = "Bearer {file:${config.nixos.system.sops.secrets."github/token".path}}";
                  };
                };
              };
            };
            catppuccin.opencode.enable = true;
          };
        }
      ];
    }
  );
}
