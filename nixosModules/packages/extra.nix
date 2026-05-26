{ lib, config, pkgs, ... }:
{
  options.nixos.packages.extra = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.packages) extra; in lib.mkIf (extra != null)
  {
    environment.systemPackages = with pkgs;
    [
      ventoy-full
      davinci-resolve
      fluffychat signal-desktop qq hexchat halloy
      appflowy notion-app-enhanced joplin-desktop logseq obsidian
      code-cursor
      warp-terminal
      rustdesk-flutter
      yubioath-flutter electrum jabref john crunch
      wgetpaste onedrive onedrivegui rclone
    ];
  };
}
