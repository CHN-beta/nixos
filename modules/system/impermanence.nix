inputs:
{
  config =
  {
    environment.persistence =
    {
      "/nix/persistent" =
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
      "/nix/rootfs/current" =
      {
        hideMounts = true;
        directories =
        [
          "/var/lib/systemd/linger"
          "/var/lib/systemd/coredump"
          "/var/lib/systemd/backlight"
          { directory = "/var/lib/docker"; mode = "0710"; }
          "/var/lib/flatpak"
        ];
      };
      "/nix/nodatacow" =
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
