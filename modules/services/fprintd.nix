inputs:
{
  options.nixos.services.fprintd = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) fprintd; in inputs.lib.mkIf (fprintd != null)
  {
    services =
    {
      fprintd =
      {
        enable = true;
        package = inputs.pkgs.fprintd.override { libfprint = inputs.pkgs.libfprint-focaltech-2808-a658; };
      };
      udev.packages = [ inputs.pkgs.libfprint-focaltech-2808-a658 ];
    };
  };
}
