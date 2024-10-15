inputs:
{
  options.nixos.services.keyd = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) keyd; in inputs.lib.mkIf (keyd != null)
  {
    services.keyd =
    {
      enable = true;
      keyboards.default =
      {
        ids = [ "*" ];
        settings =
        {
          main.rightcontrol = "overload(r_ctrl, rightcontrol)";
          "r_ctrl:C" = { left = "home"; right = "end"; up = "pageup"; down = "pagedown"; };
        };
      };
    };
  };
}
