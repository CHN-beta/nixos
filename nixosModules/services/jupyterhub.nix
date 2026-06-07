{ lib, config, ... }:
{
  options.nixos.services.jupyterhub = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) jupyterhub;
    in
    lib.mkIf (jupyterhub != null) {
      services.jupyterhub = {
        enable = true;
        port = 5374;
        extraConfig =
          let
            users = builtins.map (u: ''"${u}"'') config.nixos.user.users;
          in
          ''
            c.Authenticator.allowed_users = { ${builtins.concatStringsSep ", " users} }
          '';
        kernels = {
          python =
            let
              env = config.nixos.packages.python;
            in
            {
              displayName = "Python";
              argv = [
                env.interpreter
                "-m"
                "ipykernel_launcher"
                "-f"
                "{connection_file}"
              ];
              language = "python";
              logo32 = "${env}/${env.sitePackages}/ipykernel/resources/logo-32x32.png";
              logo64 = "${env}/${env.sitePackages}/ipykernel/resources/logo-64x64.png";
            };
          root = config.nixos.packages.root.jupyterKernelDefinition;
        };
      };
      nixos = {
        services.nginx.https."jupyterhub.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:5374";
        packages = {
          server = { };
          desktopPython = { };
          root = { };
        };
      };
    };
}
