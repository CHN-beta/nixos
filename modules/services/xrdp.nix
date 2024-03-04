inputs:
{
  options.nixos.services.xrdp = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.ints.unsigned; default = 3389; };
    hostname = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.config.nixos.services) xrdp;
    in mkIf xrdp.enable (mkMerge
    [
      {
        assertions =
        [{
          assertion = !inputs.config.nixos.system.envfs.enable;
          message = "Somehow xrdp could not start if envfs is enabled";
        }];
      }
      {
        services.xrdp =
        {
          enable = true;
          port = xrdp.port;
          openFirewall = true;
          defaultWindowManager = "${inputs.pkgs.plasma-workspace}/bin/startplasma-x11";
        };
      }
      (
        mkIf (xrdp.hostname != null)
        (
          let
            mainDomain = builtins.elemAt xrdp.hostname 0;
          in
          {
            services.xrdp =
              let keydir = inputs.config.security.acme.certs.${mainDomain}.directory;
              in { sslCert = "${keydir}/full.pem"; sslKey = "${keydir}/key.pem"; };
            nixos.services.acme =
            {
              enable = true;
              cert.${mainDomain} =
                { domains = xrdp.hostname; group = inputs.config.systemd.services.xrdp.serviceConfig.Group; };
            };
          }
        )
      )
    ]);
}
