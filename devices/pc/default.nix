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
            vfat."/dev/disk/by-uuid/E58F-416A" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/066be4fd-8617-4fe1-9654-c133c2996d33"."/" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto =
          {
            "/dev/disk/by-uuid/4c73288c-bcd8-4a7e-b683-693f9eed2d81" = { mapper = "root"; ssd = true; };
            "/dev/disk/by-uuid/4be45329-a054-4c20-8965-8c5b7ee6b35d" =
              { mapper = "swap"; ssd = true; before = [ "root" ]; };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = {};
        };
        grub =
        {
          # TODO: install windows
          # windowsEntries = { "7317-1DB6" = "Windows"; "7321-FA9C" = "Windows for malware"; };
          installDevice = "efi";
        };
        nix =
        {
          marches =
          [
            "znver2" "znver3" "znver4"
            # FXSR SAHF XSAVE
            "sandybridge"
            # FXSR PREFETCHW RDRND SAHF
            "silvermont"
            # FXSR HLE LZCNT PREFETCHW RDRND SAHF XSAVE
            "broadwell"
            # FXSR HLE LZCNT PREFETCHW RDRND SAHF SGX XSAVE
            "skylake"
            # AVX-VNNI CLDEMOTE GFNI-SSE HRESET KL LZCNT MOVDIR64B MOVDIRI PCONFIG PREFETCHW PTWRITE RDRND
            # SERIALIZE SGX WAITPKG WIDEKL XSAVE XSAVEOPT
            "alderlake"
          ];
          remote.master = { enable = true; hosts = [ "xmupc1" "xmupc2" ]; };
          githubToken.enable = true;
        };
        nixpkgs =
          { march = "znver4"; cuda = { enable = true; capabilities = [ "8.9" ]; forwardCompat = false; }; };
        kernel.patches = [ "cjktty" "hibernate-progress" ];
        networking.hostname = "pc";
        sysctl.laptop-mode = 5;
        gui.enable = true;
      };
      hardware = { cpus = [ "amd" ]; gpu = { type = "nvidia"; dynamicBoost = true; }; legion = {}; };
      packages.packageSet = "workstation";
      virtualization =
      {
        waydroid.enable = true;
        docker.enable = true;
        kvmHost = { enable = true; gui = true; autoSuspend = [ "win10" "hardconnect" ]; };
        nspawn = [ "arch" "ubuntu-22.04" "fedora" ];
      };
      services =
      {
        snapper.enable = true;
        samba =
        {
          enable = true;
          private = true;
          hostsAllowed = "192.168. 127.";
          shares =
          {
            media.path = "/run/media/chn";
            home.path = "/home/chn";
            mnt.path = "/mnt";
            share.path = "/home/chn/share";
          };
        };
        sshd = {};
        xray.client =
        {
          dnsmasq.hosts = builtins.listToAttrs
          (
            (builtins.map
              (name: { inherit name; value = "74.211.99.69"; })
              [ "mirism.one" "beta.mirism.one" "ng01.mirism.one" "initrd.vps6.chn.moe" ])
            ++ (builtins.map
              (name: { inherit name; value = "0.0.0.0"; })
              [
                "log-upload.mihoyo.com" "uspider.yuanshen.com" "ys-log-upload.mihoyo.com"
                "dispatchcnglobal.yuanshen.com"
              ])
          );
        };
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
        acme.cert."debug.mirism.one" = {};
        frpClient =
        {
          enable = true;
          serverName = "frp.chn.moe";
          user = "pc";
          stcpVisitor."yy.vnc".localPort = 6187;
        };
        nix-serve = { enable = true; hostname = "nix-store.chn.moe"; };
        smartd.enable = true;
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd.instances.root = { device = "/"; hashTableSizeMB = 4096; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
          wireguardIp = "192.168.83.3";
        };
        gamemode = { enable = true; drmDevice = 0; };
        slurm = { enable = true; cpu = { cores = 16; threads = 2; }; memoryMB = 90112; gpus."4060" = 1; };
        xrdp = { enable = true; hostname = [ "pc.chn.moe" ]; };
      };
      bugs = [ "xmunet" "backlight" "amdpstate" "suspend-hibernate-no-platform" ];
    };
    system.nixos.tags = [ "next" ];
    networking.extraHosts = "74.211.99.69 mirism.one beta.mirism.one ng01.mirism.one";
    services.colord.enable = true;
    chaotic.mesa-git.enable = true;
    specialisation =
    {
      hybrid.configuration =
      {
        nixos =
        {
          hardware.gpu = 
            { type = inputs.lib.mkForce "amd+nvidia"; prime.busId = { amd = "6:0:0"; nvidia = "1:0:0"; }; };
          services.gamemode.drmDevice = inputs.lib.mkForce 1;
        };
        system.nixos.tags = [ "hybrid" ];
      };
      xanmod.configuration =
      {
        nixos.system.kernel.variant = "xanmod-latest";
        system.nixos.tags = [ "xanmod" ];
      };
    };
  };
}
