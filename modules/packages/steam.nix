{ lib, config, pkgs, ... }:
{
  options.nixos.packages.steam = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default = if config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (config.nixos.packages) steam; in lib.mkIf (steam != null)
  {
    programs.steam =
    {
      enable = true;
      package = pkgs.steam.override (prev:
      {
        steam-unwrapped = prev.steam-unwrapped.overrideAttrs (prev:
        {
          postInstall = prev.postInstall +
          ''
            sed -i 's#Comment\[zh_CN\]=.*$#Comment\[zh_CN\]=思题慕®学习平台#' $out/share/applications/steam.desktop
          '';
        });
      });
      extraPackages = [ pkgs.openssl_1_1 ];
      extraCompatPackages = with pkgs; [ proton-ge-bin dwproton ];
      remotePlay.openFirewall = true;
      protontricks.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
  };
}
