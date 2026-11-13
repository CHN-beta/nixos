{
  config,
  pkgs,
  ...
}:
{
  config = {
    services.niks3 = {
      enable = true;
      package = pkgs.niks3;
      serverPackage = pkgs.niks3;
      httpAddr = "127.0.0.1:4999";
      cacheUrl = "https://nixcache.chn.moe";
      readProxy.enable = true;
      gc.enable = false;
      database = {
        createLocally = false;
        connectionString = "postgresql://niks3@127.0.0.1:5432/niks3?sslmode=disable";
      };
      s3 = {
        endpoint = "127.0.0.1:7070";
        bucket = "niks3";
        region = "us-east-1";
        useSSL = false;
        accessKeyFile = "${pkgs.writeText "niks3-s3-access-key" "versitygw"}";
        secretKeyFile = config.nixos.system.sops.secrets."niks3/s3-secret".path;
      };
      apiTokenFile = config.nixos.system.sops.secrets."niks3/token".path;
      signKeyFiles = [ config.nixos.system.sops.secrets."store/signingKey".path ];
    };
    nixos = {
      services = {
        postgresql.instances.niks3 = { };
        nginx.https."nixcache.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:4999";
      };
      system.sops = {
        secrets = {
          "store/signingKey".owner = "niks3";
          "niks3/s3-secret" = {
            key = "versitygw/secret";
            owner = "niks3";
          };
          "niks3/token" = {
            owner = "niks3";
          };
        };
        templates."niks3.env".content = ''
          PGPASSWORD=${config.nixos.system.sops.placeholder."postgresql/niks3"}
        '';
      };
    };
    systemd.services = {
      versitygw.serviceConfig.StateDirectory = [ "versitygw/niks3" ];
      niks3 = {
        after = [
          "postgresql.service"
          "versitygw.service"
        ];
        requires = [
          "postgresql.service"
          "versitygw.service"
        ];
        restartTriggers = [ config.nixos.system.sops.templates."niks3.env".content ];
        serviceConfig.EnvironmentFile = config.nixos.system.sops.templates."niks3.env".path;
      };
    };
  };
}
