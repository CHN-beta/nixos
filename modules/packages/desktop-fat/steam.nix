inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "desktop-fat" inputs.config.nixos.packages._packageSets)
    {
      programs.steam =
      {
        enable = true;
        package = inputs.pkgs.steam.override (prev:
        {
          steam = prev.steam.overrideAttrs (prev:
          {
            postInstall = prev.postInstall +
            ''
              sed -i 's#Comment\[zh_CN\]=.*$#Comment\[zh_CN\]=思题慕®学习平台#' $out/share/applications/steam.desktop
            '';
          });
        });
      };
    };
}
