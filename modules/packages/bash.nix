{
  config.nixos.user.sharedModules = [(homeInputs:
  {
    config =
    {
      # set bash history file path, avoid overwriting zsh history
      programs.bash = { enable = true; historyFile =  "${homeInputs.config.xdg.dataHome}/bash/bash_history"; };
      home.shell.enableBashIntegration = true;
    };
  })];
}
