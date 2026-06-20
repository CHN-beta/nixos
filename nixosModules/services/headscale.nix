{
  lib,
  config,
  pkgs,
  self,
  ...
}:
{
  options.nixos.services.headscale = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) headscale;
    in
    lib.mkIf (headscale != null) {
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
              enabled = true;
              region_id = 999;
              region_code = "chn";
              region_name = "CHN DERP";
              verify_clients = true;
              stun_listen_addr = "0.0.0.0:3479";
              automatically_add_embedded_derp_region = true;
            };
            urls = [ ];
            paths = [
              (pkgs.runCommand "custom-derp.json" { } ''
                ${pkgs.jq}/bin/jq '.Regions[].Nodes[].stunOnly = true' "${self.src.tailscaleOfficialDerp}" > $out
              '')
            ];
          };
        };
      };
      networking.firewall.allowedUDPPorts = [ 3479 ];
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
