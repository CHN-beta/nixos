inputs:
{
  config.boot.plymouth =
  {
    # TODO: race condition, try enable it at next release
    enable = false;
    theme = "mac-style";
    themePackages = [((inputs.pkgs.callPackage inputs.flakeInputs.mac-style {}).overrideAttrs (prev:
    {
      installPhase = prev.installPhase
        + ''cp ${./nix-doge.png} $out/share/plymouth/themes/mac-style/images/header-image.png'';
    }))];
  };
}
