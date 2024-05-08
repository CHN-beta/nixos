inputs:
{
  options.nixos.services.nginx.applications.nekomia = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config = let inherit (inputs.config.nixos.services.nginx.applications) nekomia; in inputs.lib.mkIf nekomia.enable
  {
    nixos.services.nginx.https."nekomia.moe".location."/".static =
    {
      root =
        let drv = let pandoc = "${inputs.pkgs.pandoc}/bin/pandoc"; in inputs.pkgs.runCommand "build" {}
        ''
          mkdir -p $out
          ${pandoc} -f markdown -t html5 -o $out/index.html ${./index.md}
        '';
        in "${drv}";
      index = [ "index.html" ];
      charset = "utf-8";
    };
  };
}
