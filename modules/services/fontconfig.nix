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
        fonts = with inputs.pkgs;
          [ noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono nerdfonts ];
        fontconfig.defaultFonts =
        {
          emoji = [ "Noto Color Emoji" ];
          monospace = [ "Noto Sans Mono CJK SC" "Sarasa Mono SC" "DejaVu Sans Mono"];
          sansSerif = [ "Noto Sans CJK SC" "Source Han Sans SC" "DejaVu Sans" ];
          serif = [ "Noto Serif CJK SC" "Source Han Serif SC" "DejaVu Serif" ];
        };
      };
    };
}
