{
  lib,
  config,
  self,
  ...
}:
{
  config = lib.mkIf (config.nixos.model.variant == "desktop") {
    environment = {
      systemPackages = [ self.inputs.llm-agents.packages.x86_64-linux.opencode ];
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
          xdg.configFile."opencode/plugins/opencode-antigravity-auth".source =
            self.inputs.opencode-antigravity-auth;
        };
      }
    ];
  };
}
