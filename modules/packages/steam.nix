inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop-extra" inputs.config.nixos.packages._packageSets)
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
