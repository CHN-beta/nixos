inputs:
{
  options.nixos.services.speedtest = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "409test.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) speedtest; in inputs.lib.mkIf (speedtest != null)
  {
    nixos.services =
    {
      phpfpm.instances.speedtest = {};
      nginx.https.${speedtest.hostname} = let pkg = inputs.pkgs.localPkgs.speedtest; in
      {
        global.root = "${pkg}";
        location."~ ^.+?\.php(/.*)?$".php =
          { root = "${pkg}"; fastcgiPass = inputs.config.nixos.services.phpfpm.instances.speedtest.fastcgi; };
      };
    };
  };
}
