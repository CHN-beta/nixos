inputs:
{
  config.boot.plymouth =
  {
    enable = true;
    theme = "mac-style";
    themePackages = [((inputs.pkgs.callPackage inputs.topInputs.mac-style {}).overrideAttrs (prev:
    {
      installPhase = prev.installPhase
        + ''cp ${./nix-doge.png} $out/share/plymouth/themes/mac-style/images/header-image.png'';
    }))];
  };
}
