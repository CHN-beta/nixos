{ pkgs, ... }:
{
  config =
  {
    programs.yazi.enable = true;
    nixos.user.sharedModules =
    [{
      config.programs.yazi =
      {
        enable = true;
        keymap.mgr.append_keymap =
        [
          { on = "T"; run = "shell --orphan ghostty"; }
          { on = [ "c" "a" "a" ]; run = "plugin compress"; }
        ];
        plugins = { inherit (pkgs.yaziPlugins) compress; };
      };
    }];
  };
}
