{
  lib,
  config,
  self,
  pkgs,
  ...
}:
{
  config = {
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
    nixos.system.sops.secrets = {
      "github/token".mode = "0444";
      "opencode/mineru".mode = "0444";
    };
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
                dockerhub = {
                  type = "local";
                  command = [ (lib.getExe pkgs.localPkgs.dockerhub-mcp) ];
                };
                openalex = {
                  type = "local";
                  command =
                    pkgs.python3Packages.alex-mcp
                    |> (
                      p:
                      pkgs.writeShellScript "alex-mcp" ''
                        export OPENALEX_MAILTO=chn@chn.moe
                        exec ${lib.getExe p}
                      ''
                    )
                    |> lib.singleton;
                };
                mineru = {
                  type = "local";
                  command =
                    pkgs.python3Packages.mineru-mcp
                    |> (
                      p:
                      pkgs.writeShellScript "mineru-mcp" ''
                        export MINERU_API_KEY=$(cat ${config.nixos.system.sops.secrets."opencode/mineru".path})
                        exec ${lib.getExe p} stdio
                      ''
                    )
                    |> lib.singleton;
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
  };
}
