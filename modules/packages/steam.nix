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
      package = inputs.lib.mkIf (inputs.config.nixos.hardware.steamdeck == null) (inputs.pkgs.steam.override (prev:
      {
        steam = prev.steam.overrideAttrs (prev:
        {
          postInstall = prev.postInstall +
          ''
            sed -i 's#Comment\[zh_CN\]=.*$#Comment\[zh_CN\]=思题慕®学习平台#' $out/share/applications/steam.desktop
          '';
        });
      }));
      extraCompatPackages = [ inputs.pkgs.proton-ge-bin ];
      remotePlay.openFirewall = true;
      protontricks.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    # not easy to override steamdeck's steam package env, just write env vars to global
    environment.sessionVariables = inputs.lib.mkIf (inputs.config.nixos.hardware.steamdeck != null)
    {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS =
        inputs.lib.makeSearchPathOutput "steamcompattool" "" inputs.config.programs.steam.extraCompatPackages;
    };
  };
}
