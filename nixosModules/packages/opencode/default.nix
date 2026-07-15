{
  lib,
  config,
  self,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.nixos.model.variant == "desktop") {
    environment = {
      systemPackages = [
        self.inputs.llm-agents.packages.x86_64-linux.opencode
        # needed by opencode-notifier
        pkgs.libnotify
        self.inputs.llm-agents.packages.x86_64-linux.agent-browser
        self.inputs.camoufox-nix.packages.x86_64-linux.camofox-browser
      ];
      persistence."/nix/persistent".users.chn.directories = [ ".cache/opencode" ];
    };
    nixos.system.sops.secrets."github/token".mode = "0444";
    nixos.user.sharedModules = [
      {
        config = {
          programs.opencode = {
            enable = true;
            package = self.inputs.llm-agents.packages.x86_64-linux.opencode;
            enableMcpIntegration = true;
            settings = {
              plugin = [
                "opencode-antigravity-auth@1.6.0"
                "@mohak34/opencode-notifier@0.2.8"
              ];
              # copy from https://github.com/NoeFabris/opencode-antigravity-auth#models
              provider.google = (builtins.fromJSON (builtins.readFile ./google.json)).provider.google;
              autoupdate = false;
              mcp = {
                openalex = {
                  type = "local";
                  command = [
                    (lib.getExe (
                      pkgs.runCommand "alex-mcp"
                        {
                          nativeBuildInputs = [ pkgs.makeWrapper ];
                          meta.mainProgram = "alex-mcp";
                        }
                        ''
                          mkdir -p $out/bin
                          makeWrapper ${lib.getExe pkgs.python3Packages.alex-mcp} $out/bin/alex-mcp \
                            --set OPENALEX_MAILTO chn@chn.moe
                        ''
                    ))
                  ];
                };
                camoufox = {
                  type = "local";
                  command = [
                    (lib.getExe self.inputs.camoufox-nix.packages.x86_64-linux.camofox-mcp)
                  ];
                };
                nixos = {
                  type = "local";
                  command = [
                    "nix"
                    "run"
                    "github:utensils/mcp-nixos"
                    "--"
                  ];
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
  };
}
