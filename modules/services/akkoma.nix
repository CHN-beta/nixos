inputs:
{
  options.nixos.services.akkoma = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "akkoma.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) akkoma;
      inherit (inputs.lib) mkIf;
    in mkIf akkoma.enable
    {
      services.akkoma =
      {
        enable = true;
        config.":pleroma" =
        {
          "Pleroma.Web.Endpoint".url.host = akkoma.hostname;
          "Pleroma.Repo" =
          {
            adapter = (inputs.pkgs.formats.elixirConf { }).lib.mkRaw "Ecto.Adapters.Postgres";
            hostname = "127.0.0.1";
            username = "akkoma";
            password._secret = inputs.config.sops.secrets."akkoma/db".path;
            database = "akkoma";
          };
          ":instance" =
          {
            name = "艹";
            email = "grass@grass.squre";
            description = "艹艹艹艹艹";
          };
        };
      };
      nixos.services =
      {
        nginx =
        {
          enable = true;
          https."${akkoma.hostname}" =
          {
            global.tlsCert = "/var/lib/akkoma";
            location."/".proxy = { upstream = "http://127.0.0.1:4000"; websocket = true; };
          };
        };
        postgresql.instances.akkoma = {};
      };
      sops.secrets."akkoma/db" = { owner = "akkoma"; key = "postgresql/akkoma"; };
    };
}
