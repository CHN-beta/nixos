inputs:
{
  options.nixos.packages.bash = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) bash; in inputs.lib.mkIf (bash != null)
  {
    nixos.user.sharedModules = [(homeInputs:
    {
      config =
      {
        # set bash history file path, avoid overwriting zsh history
        programs.bash = { enable = true; historyFile =  "${homeInputs.config.xdg.dataHome}/bash/bash_history"; };
        home.shell.enableBashIntegration = true;
      };
    })];
  };
}
