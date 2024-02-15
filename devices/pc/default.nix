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
            vfat."/dev/disk/by-uuid/3F57-0EBE" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/02e426ec-cfa2-4a18-b3a5-57ef04d66614"."/" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto =
          {
            "/dev/disk/by-uuid/55fdd19f-0f1d-4c37-bd4e-6df44fc31f26" = { mapper = "root"; ssd = true; };
            "/dev/disk/by-uuid/4be45329-a054-4c20-8965-8c5b7ee6b35d" =
              { mapper = "swap"; ssd = true; before = [ "root" ]; };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
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
        };
        nixpkgs =
          { march = "znver4"; cuda = { enable = true; capabilities = [ "8.9" ]; forwardCompat = false; }; };
        kernel.patches = [ "cjktty" "lantian" ];
        networking.hostname = "pc";
        sysctl.laptop-mode = 5;
      };
      hardware =
      {
        cpus = [ "amd" ];
        gpu.type = "amd+nvidia";
        bluetooth.enable = true;
        joystick.enable = true;
        printer.enable = true;
        sound.enable = true;
        legion.enable = true;
      };
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
        fontconfig.enable = true;
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
        sshd.enable = true;
        xray.client =
        {
          enable = true;
          serverAddress = "74.211.99.69";
          serverName = "vps6.xserver.chn.moe";
          dns =
          {
            extraInterfaces = [ "docker0" ];
            hosts =
            {
              "mirism.one" = "74.211.99.69";
              "beta.mirism.one" = "74.211.99.69";
              "ng01.mirism.one" = "74.211.99.69";
              "debug.mirism.one" = "127.0.0.1";
              "initrd.vps6.chn.moe" = "74.211.99.69";
              "nix-store.chn.moe" = "127.0.0.1";
              "initrd.nas.chn.moe" = "192.168.1.185";
            };
          };
        };
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
        acme = { enable = true; cert."debug.mirism.one" = {}; };
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
        beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 2048; threads = 4; }; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
          wireguardIp = "192.168.83.3";
        };
        gamemode = { enable = true; drmDevice = 0; };
      };
      bugs = [ "xmunet" "backlight" "amdpstate" ];
    };
    # use plasma-x11 as default, instead of plasma-wayland
    services.xserver.displayManager.defaultSession = inputs.lib.mkForce "plasma";
    virtualisation.virtualbox.host = { enable = true; enableExtensionPack = true; };
    hardware.nvidia.forceFullCompositionPipeline = true;
    home-manager.users.chn.config.programs.plasma.startup.autoStartScript.xcalib.text =
      "${inputs.pkgs.xcalib}/bin/xcalib -d :0 ${./color/TPLCD_161B_Default.icm}";
  };
}
