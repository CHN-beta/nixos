{ lib, config, pkgs, ... }:
{
  options.nixos.services.garage = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      metadataDir = lib.mkOption { type = lib.types.nonEmptyStr; default = "/var/lib/garage/meta"; };
      dtataDir = lib.mkOption { type = lib.types.nonEmptyStr; default = "/var/lib/garage/data"; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) garage; in lib.mkIf (garage != null)
  {
    services.garage =
    {
      enable = true;
      package = pkgs.garage_2;
      settings =
      {
        metadata_dir = garage.metadataDir;
        data_dir = garage.dtataDir;
        db_engine = "lmdb";
        replication_factor = 1;
        compression_level = "none";
        block_size = "4M";
        s3_api = { api_bind_addr = "127.0.0.1:3900"; s3_region = "us-east-1"; };
        rpc_bind_addr = "127.0.0.1:3901";
      };
      environmentFile = config.nixos.system.sops.templates."garage/env".path;
    };
    users =
    {
      users.garage =
      {
        uid = config.nixos.user.uid.garage;
        group = "garage";
        home = "/var/lib/garage";
        createHome = true;
        isSystemUser = true;
      };
      groups.garage.gid = config.nixos.user.gid.garage;
    };
    nixos =
    {
      services.nginx.https."garage.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:3900";
      system.sops =
      {
        secrets."garage/rpc" = {};
        templates."garage/env".content =
        ''
          GARAGE_RPC_SECRET=${config.nixos.system.sops.placeholder."garage/rpc"}
        '';
      };
    };
  };
}
