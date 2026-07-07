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
      ];
      persistence."/nix/persistent".users.chn.directories = [ ".cache/opencode" ];
    };
    nixos.user.sharedModules = [
      {
        config = {
          programs = {
            opencode = {
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
              };
            };
            mcp = {
              enable = true;
              servers = {
                nixos = {
                  command = "nix";
                  args = [
                    "run"
                    "github:utensils/mcp-nixos"
                    "--"
                  ];
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
