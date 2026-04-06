inputs:
{
  config = inputs.lib.mkIf (builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ])
  {
    fonts =
    {
      fontDir.enable = true;
      packages = with inputs.pkgs;
      [
        noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono hack-font inter
        noto-fonts-color-emoji roboto sarasa-gothic source-han-mono wqy_microhei wqy_zenhei
        corefonts windows-fonts dejavu_fonts nerd-fonts.fira-code
        noto-fonts-cjk-sans-static noto-fonts-cjk-serif-static
        # needed by typst may template
        lxgw-wenkai libertinus windows-fonts
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
