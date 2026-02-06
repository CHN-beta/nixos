inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        fileSystems =
        {
          mount =
          {
            btrfs =
            {
              "/dev/disk/by-partlabel/vps9-boot"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:06:0a.0";
        nixpkgs.march = "znver3";
        initrd.sshd = {};
      };
      services =
      {
        sshd = {};
        fail2ban = {};
        xray.server.serverName = "xserver2.vps9.chn.moe";
        nginx.streamProxy.map = builtins.listToAttrs (builtins.map
          (site: { name = "${site}.chn.moe"; value.upstream.address = "tinc0.nas.chn.moe"; })
          [
            "xn--s8w913fdga" "matrix" "send" "git" "grafana" "peertube" "rsshub" "misskey" "synapse" "vaultwarden"
            "nextcloud" "freshrss" "huginn" "api" "webdav" "photo" "readeck"
          ]);
      };
    };
  };
}
