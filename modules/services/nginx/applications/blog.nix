inputs:
{
  options.nixos.services.nginx.applications.blog = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services.nginx.applications) blog; in inputs.lib.mkIf (blog != null)
    {
      nixos.services.nginx.https."blog.chn.moe".location."/".static =
      {
        root = builtins.toString inputs.topInputs.self.packages.x86_64-linux.blog;
        index = [ "index.html" ];
        tryFiles = [ "$uri" "$uri/" ];
      };
    };
}
