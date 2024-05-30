inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
  {
    home-manager.users.chn.config.programs.git =
    {
      enable = true;
      package = inputs.pkgs.gitFull;
      extraConfig =
      {
        core.editor = if inputs.config.nixos.system.gui.preferred then "code --wait" else "vim";
        http.postBuffer = 624288000;
        advice.detachedHead = false;
        merge.conflictstyle = "diff3";
        diff.colorMoved = "default";
        lfs =
        {
          concurrenttransfers = 10;
          activitytimeout = 3600;
          dialtimeout = 3600;
          keepalive = 3600;
          tlstimeout = 3600;
          transfer.maxretries = 1;
        };
      };
      delta =
      {
        enable = true;
        options =
        {
          side-by-side = true;
          navigate = true;
          syntax-theme = "GitHub";
          light = true;
          zero-style = "syntax white";
          line-numbers-zero-style = "#ffffff";
        };
      };
    };
    programs.git =
    {
      enable = true;
      package = inputs.pkgs.gitFull;
      lfs.enable = true;
      config =
      {
        init.defaultBranch = "main";
        core.quotepath = false;
      };
    };
  };
}
