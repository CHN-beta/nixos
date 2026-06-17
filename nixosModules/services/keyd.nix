{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.keyd = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) keyd;
    in
    lib.mkIf (keyd != null) {
      services.keyd = {
        enable = true;
        keyboards.default = {
          ids = [ "*" ];
          settings = {
            main = {
              rightcontrol = "overload(r_ctrl, rightcontrol)";
              prog4 = "sysrq";
              capslock = "leftmeta";
              leftmeta = "capslock";
            };
            "r_ctrl:C" = {
              left = "home";
              right = "end";
              up = "pageup";
              down = "pagedown";
            };
          };
        };
      };
      environment = {
        # keyd makes touchpad disable-when-typing does not work, this fixes it
        etc."libinput/local-overrides.quirks".text = ''
          [Serial Keyboards]
          MatchUdevType=keyboard
          MatchName=keyd virtual keyboard
          AttrKeyboardIntegration=internal
        '';
        systemPackages = [ pkgs.keyd ];
      };
    };
}
