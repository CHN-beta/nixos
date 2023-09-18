inputs:
{
  options.nixos.system.impermanence = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    persistence = mkOption { type = types.nonEmptyStr; default = "/nix/persistent"; };
    root = mkOption { type = types.nonEmptyStr; default = "/nix/rootfs/current"; };
    nodatacow = mkOption { type = types.nullOr types.nonEmptyStr; default = "/nix/nodatacow"; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.system) impermanence;
    in mkIf impermanence.enable
    {
      environment.persistence =
      {
        "${impermanence.persistence}" =
        {
          hideMounts = true;
          directories =
          [
            "/etc/NetworkManager/system-connections"
            "/home"
            "/root"
            "/var/db"
            "/var/lib"
            "/var/log"
            "/var/spool"
            "/var/backup"
          ];
          files =
          [
            "/etc/machine-id"
            "/etc/ssh/ssh_host_ed25519_key.pub"
            "/etc/ssh/ssh_host_ed25519_key"
            "/etc/ssh/ssh_host_rsa_key.pub"
            "/etc/ssh/ssh_host_rsa_key"
          ];
        };
        "${impermanence.root}" =
        {
          hideMounts = true;
          directories = [ "/var/lib/systemd/linger" ]
            ++ (if inputs.config.services.xserver.displayManager.sddm.enable then
              [{ directory = "/var/lib/sddm"; user = "sddm"; group = "sddm"; mode = "0700"; }] else []);
        };
        "${impermanence.nodatacow}" =
        {
          hideMounts = true;
          directories =
            (
              if inputs.config.nixos.services.postgresql.enable then let user = inputs.config.users.users.postgres; in
                [{ directory = "/var/lib/postgresql"; user = user.name; group = user.group; mode = "0750"; }]
              else []
            )
            ++ (if inputs.config.nixos.services.meilisearch.instances != {} then [ "/var/lib/meilisearch" ] else []);
        };
      };
    };
}
