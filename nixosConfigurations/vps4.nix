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
          luks."/dev/disk/by-uuid/bf7646f9-496c-484e-ada0-30335da57068" = { mapper = "root"; ssd = true; };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
        nixpkgs.march = "znver2";
        initrd.sshd = {};
      };
      services =
      {
        sshd = {};
        fail2ban = {};
        xray.server.serverName = "xserver2.vps4.chn.moe";
        gatus = {};
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
