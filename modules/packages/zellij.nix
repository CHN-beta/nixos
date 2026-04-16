{ pkgs, ... }:
{
  config =
  {
    environment.systemPackages = [ pkgs.zellij ];
    nixos.user.sharedModules =
    [{
      config.programs.zellij =
      {
        enable = true;
        settings = { scroll_buffer_size = 100000000; show_startup_tips = false; show_release_notes = false; };
      };
    }];
  };
}
