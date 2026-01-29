{ lib, config, ... }:
{
  config = lib.mkIf (config.nixos.packages.git != null)
  {
    home-manager.users.chn.config.programs =
    {
      git =
      {
        enable = true;
        settings =
        {
          core.editor = if config.nixos.model.type == "desktop" then "code --wait" else "hx"; 
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
          user = { name = "Haonan Chen"; email = "chn@chn.moe"; };
        };
      };
      delta =
      {
        enable = true;
        enableGitIntegration = true;
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
