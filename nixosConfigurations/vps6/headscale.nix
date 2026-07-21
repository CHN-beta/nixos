{
  config,
  pkgs,
  ...
}:
{
  config = {
    services.headscale = {
      enable = true;
      port = 6538;
      settings = {
        server_url = "https://headscale.chn.moe";
        prefixes.v4 = "100.97.101.0/24";
        database.postgres = {
          user = "headscale";
          port = 5432;
          password_file = config.nixos.system.sops.secrets."headscale/postgresql".path;
          name = "headscale";
          host = "127.0.0.1";
        };
        dns = {
          base_domain = "ts.chn.moe";
          override_local_dns = false;
        };
        derp = {
          server = {
            enabled = false;
            automatically_add_embedded_derp_region = false;
          };
          urls = [ ];
          # urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
          paths = [
            (pkgs.writeText "derp.yaml" ''
              regions:
                900:
                  regionid: 900
                  regioncode: cn
                  regionname: China Custom DERP
                  nodes:
                    - name: nas
                      regionid: 900
                      hostname: derp.chn.moe
                      stunport: 3478
                      stunonly: false
                      derpport: 3443
            '')
          ];
        };
      };
    };
    nixos = {
      services = {
        nginx.https."headscale.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:6538";
        postgresql.instances.headscale = { };
      };
      system.sops.secrets."headscale/postgresql" = {
        key = "postgresql/headscale";
        owner = "headscale";
      };
    };
  };
}
