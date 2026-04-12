{ lib, config, pkgs, ... }:
{
  options.nixos.services.jupyterhub = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) jupyterhub; in lib.mkIf (jupyterhub != null)
  {
    services.jupyterhub =
    {
      enable = true;
      port = 5374;
      extraConfig = let users = builtins.map (u: ''"${u}"'') config.nixos.user.users; in
      ''
        c.Authenticator.allowed_users = { ${builtins.concatStringsSep ", " users} }
      '';
      kernels =
      {
        python3 = (pkgs.jupyter-kernel.override { python3 = config.nixos.packages.python; }).default.python3;
        root = config.nixos.packages.root.jupyterKernelDefinition;
      };
    };
    nixos =
    {
      services.nginx.https."jupyterhub.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:5374";
      packages = { server = {}; desktopPython = {}; root = {}; };
    };
  };
}
