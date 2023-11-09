inputs:
{
  options.nixos.services.kmscon = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) kmscon;
    in mkIf kmscon.enable
    {
      services.kmscon =
      {
        enable = true;
        fonts = [{ name = "FiraCode Nerd Font Mono"; package = inputs.pkgs.nerdfonts; }];
      };
    };
}
