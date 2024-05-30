inputs:
{
  options.nixos.system.impermanence = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = true; };
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
            "/var/db"
            "/var/lib"
            "/var/log"
            "/var/spool"
            "/var/backup"
            { directory = "/var/lib/docker/volumes"; mode = "0710"; }
            "/srv"
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
          directories =
          [
            "/var/lib/systemd/linger"
            "/var/lib/systemd/coredump"
            "/var/lib/systemd/backlight"
            { directory = "/var/lib/docker"; mode = "0710"; }
            "/var/lib/flatpak"
          ]
          ++ (if inputs.config.services.displayManager.sddm.enable then
            [{ directory = "/var/lib/sddm"; user = "sddm"; group = "sddm"; mode = "0700"; }] else []);
        }
        // (if builtins.elem "chn" inputs.config.nixos.user.users then
        {
          users.chn =
          {
            directories = [ ".cache" ".config/fontconfig" ];
          };
        } else {});
        "${impermanence.nodatacow}" =
        {
          hideMounts = true;
          directories =
            [{ directory = "/var/log/journal"; user = "root"; group = "systemd-journal"; mode = "u=rwx,g=rx+s,o=rx"; }]
            ++ (
              if inputs.config.nixos.virtualization.kvmHost.enable then
                [{ directory = "/var/lib/libvirt/images"; mode = "0711"; }]
              else []
            );
        };
      };
    };
}
