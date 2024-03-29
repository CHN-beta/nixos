inputs:
{
  options.nixos.services.xrdp = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.ints.unsigned; default = 3389; };
    hostname = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
    optimise =
    {
      type = mkOption { type = types.nullOr (types.enum [ "nvidia" "glamor" ]); default = null; };
      nvidiaBusId = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    };
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
          assertion = (xrdp.optimise.type == "nvidia") -> (xrdp.optimise.nvidiaBusId != null);
          message = "nvidiaBusId must be set if optimise type is nvidia";
        }];
      }
      {
        services.xrdp =
        {
          enable = true;
          package = mkIf (xrdp.optimise.type != null) (inputs.pkgs.xrdp.override
          {
            variant = xrdp.optimise.type;
            inherit (xrdp.optimise) nvidiaBusId;
            nvidiaPackage = inputs.config.hardware.nvidia.package;
          });
          port = xrdp.port;
          openFirewall = true;
          defaultWindowManager = "${inputs.pkgs.plasma-workspace}/bin/startplasma-x11";
        };
        environment.etc.xrdp.source = "${inputs.config.services.xrdp.package}/etc/xrdp";
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
            nixos.services.acme.cert.${mainDomain} =
              { domains = xrdp.hostname; group = inputs.config.systemd.services.xrdp.serviceConfig.Group; };
          }
        )
      )
    ]);
}
