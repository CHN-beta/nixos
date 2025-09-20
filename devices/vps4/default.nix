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
              "/dev/disk/by-uuid/403fe853-8648-4c16-b2b5-3dfa88aee351"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
        nixpkgs.march = "znver2";
        initrd.sshd = {};
        network = {};
      };
      services =
      {
        sshd = {};
        fail2ban = {};
        xray.server.serverName = "xserver2.vps4.chn.moe";
        nginx.streamProxy.map = builtins.listToAttrs (builtins.map
          (site: { name = "${site}.chn.moe"; value.upstream.address = "wg0.nas.chn.moe"; })
          [
            "xn--s8w913fdga" "matrix" "send" "git" "grafana" "peertube" "rsshub" "misskey" "synapse" "vaultwarden"
            "photoprism" "nextcloud" "freshrss" "huginn" "api" "webdav" "chat"
          ]);
      };
    };
  };
}
