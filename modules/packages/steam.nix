inputs:
{
  options.nixos.packages.steam = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) steam; in inputs.lib.mkIf (steam != null)
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
      extraPackages = [ inputs.pkgs.openssl_1_1 ];
      extraCompatPackages = [ inputs.pkgs.proton-ge-bin ];
      remotePlay.openFirewall = true;
      protontricks.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };
}
