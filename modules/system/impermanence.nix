inputs:
{
  config = inputs.lib.mkMerge
  [
    # generic settings
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
    }
    # /home/user and /home/user/.cache
    {
      environment.persistence =
      {
        "/nix/persistent".directories =
          # mount user directory if not a cluster worker
          inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null != "worker") (builtins.map
            (user: { directory = "/home/${user}"; inherit user; group = user; mode = "0700"; })
            (builtins.filter
              (user: !(user == "chn" && inputs.config.nixos.model.type == "desktop"))
              inputs.config.nixos.user.users));
        "/nix/rootfs/current".directories = builtins.map
          (user: { directory = "/home/${user}/.cache"; inherit user; group = user; mode = "0700"; })
          inputs.config.nixos.user.users;
      };
    }
    # on cluster worker, dirs like /home/user/.config should always be separately mounted
    {
      environment.persistence = inputs.lib.mkIf (inputs.config.nixos.model.cluster.nodeType or null == "worker")
      {
        "/nix/persistent".directories = builtins.filter
          # these dirs have been specified elsewhere
          (dir: !(builtins.elem dir.directory [ "/home/chn/.config" "/home/chn/.ssh" ]))
          (builtins.concatLists (builtins.map
            (user: builtins.map
              (dir: { directory = "/home/${user}/${dir}"; inherit user; group = user; mode = "0700"; })
              [ ".config" ".local" ".ssh" ".mozilla" ".zsh" ".yubico" ])
            inputs.config.nixos.user.users));
      };
    }
  ];
}
