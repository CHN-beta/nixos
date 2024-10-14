inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.packages.git != null)
  {
    home-manager.users.chn.config.programs.git =
    {
      enable = true;
      package = inputs.pkgs.gitFull;
      extraConfig =
      {
        core.editor = "hx";
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
  };
}
