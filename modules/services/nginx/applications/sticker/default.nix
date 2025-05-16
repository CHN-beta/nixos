inputs:
{
  options.nixos.services.nginx.applications.sticker = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services.nginx.applications) sticker; in inputs.lib.mkIf (sticker != null)
  {
    nixos.services.nginx.https."sticker.chn.moe".location."/".static =
    {
      root = builtins.toString (inputs.pkgs.runCommand "web" {}
      ''
        mkdir -p $out
        cp -r ${inputs.topInputs.stickerpicker}/web/* $out
        chmod -R +w $out
        cp -r ${./web}/* $out
      '');
      index = [ "index.html" ];
    };
  };
}
