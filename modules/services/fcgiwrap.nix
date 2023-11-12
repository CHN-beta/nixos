inputs:
{
  options.nixos.services.fcgiwrap = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) fcgiwrap;
      inherit (inputs.lib) mkIf;
    in mkIf fcgiwrap.enable
    {
      nixos.services.nginx.enable = true;
      services.fcgiwrap =
      {
        enable = true;
        user = inputs.config.users.users.nginx.name;
        group = inputs.config.users.users.nginx.group;
      };
    };
}
