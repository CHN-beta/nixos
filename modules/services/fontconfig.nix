inputs:
{
  options.nixos.services.fontconfig = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) fontconfig;
    in mkIf fontconfig.enable
    {
      fonts =
      {
        fontDir.enable = true;
        packages = with inputs.pkgs;
        [
          noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono nerdfonts hack-font inter
          noto-fonts-color-emoji roboto sarasa-gothic source-han-mono wqy_microhei wqy_zenhei noto-fonts-cjk
          noto-fonts-emoji
        ];
        fontconfig.defaultFonts =
        {
          emoji = [ "Noto Color Emoji" ];
          monospace = [ "Hack" "Source Han Mono SC" ];
          sansSerif = [ "Inter" "Liberation Sans" "Source Han Sans SC" ];
          serif = [ "Liberation Serif" "Source Han Serif SC" ];
        };
      };
      nixos.user.sharedModules = [{ config.xdg.configFile."fontconfig/conf.d/10-hm-fonts.conf".force = true; }];
    };
}
