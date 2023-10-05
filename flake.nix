{
  description = "CNH's NixOS Flake";

  inputs =
  {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:CHN-beta/nixpkgs/nixos-unstable";
    home-manager = { url = "github:nix-community/home-manager/release-23.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix =
    {
      url = "github:Mic92/sops-nix";
      inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs"; };
    };
    touchix = { url = "github:CHN-beta/touchix"; inputs.nixpkgs.follows = "nixpkgs"; };
    aagl = { url = "github:ezKEa/aagl-gtk-on-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur.url = "github:nix-community/NUR";
    nixos-cn = { url = "github:nixos-cn/flakes"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-xddxdd = { url = "github:xddxdd/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-vscode-extensions =
    {
      url = "github:nix-community/nix-vscode-extensions?rev=50c4bce16b93e7ca8565d51fafabc05e9f0515da";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = { url = "github:thiagokokada/nix-alien"; inputs.nix-index-database.follows = "nix-index-database"; };
    impermanence.url = "github:nix-community/impermanence";
    qchem = { url = "github:Nix-QChem/NixOS-QChem"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixd = { url = "github:nix-community/nixd"; inputs.nixpkgs.follows = "nixpkgs"; };
    napalm = { url = "github:nix-community/napalm"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixpak = { url = "github:nixpak/nixpak"; inputs.nixpkgs.follows = "nixpkgs"; };
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    pnpm2nix-nzbr = { url = "github:CHN-beta/pnpm2nix-nzbr"; inputs.nixpkgs.follows = "nixpkgs"; };
    lmix = { url = "github:CHN-beta/lmix"; inputs.nixpkgs.follows = "nixpkgs"; };
    dguibert-nur-packages = { url = "github:CHN-beta/dguibert-nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = inputs:
    let
      localLib = import ./local/lib inputs.nixpkgs.lib;
    in
    {
      packages.x86_64-linux =
      {
        default = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "systems"
          (builtins.concatStringsSep "\n" (builtins.map
            (system: builtins.toString inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel)
            [ "pc" "vps6" "vps7" "nas" ]));
      }
      // (
        builtins.listToAttrs (builtins.map
          (system:
          {
            name = system;
            value = inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel;
          })
          [ "pc" "vps6" "vps7" "nas" "yoga" ])
      );
      nixosConfigurations = builtins.listToAttrs (builtins.map
        (system:
        {
          name = system.name;
          value = inputs.nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            specialArgs = { topInputs = inputs; inherit localLib; };
            modules = localLib.mkModules
            (
              [
                (inputs: { config.nixpkgs.overlays = [(final: prev:
                  { localPackages = (import ./local/pkgs { inherit (inputs) lib; pkgs = final; }); })]; })
                ./modules
              ]
              ++ system.value
            );
          };
        })
        (localLib.attrsToList
        {
          "pc" =
          [
            (inputs: { config.nixos =
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
                    "/dev/md/swap" = { mapper = "swap"; ssd = true; before = [ "root" ]; };
                  };
                  mdadm =
                    "ARRAY /dev/md/swap metadata=1.2 name=pc:swap UUID=2b546b8d:e38007c8:02990dd1:df9e23a4";
                  swap = [ "/dev/mapper/swap" ];
                  resume = "/dev/mapper/swap";
                  rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
                };
                grub =
                {
                  windowsEntries = { "7317-1DB6" = "Windows"; "7321-FA9C" = "Windows for malware"; };
                  installDevice = "efi";
                };
                nix =
                {
                  marches =
                  [
                    "alderlake"
                    # CX16
                    "sandybridge"
                    # CX16 SAHF FXSR
                    "silvermont"
                    # RDSEED MWAITX SHA CLZERO CX16 SSE4A ABM CLFLUSHOPT WBNOINVD
                    "znver2" "znver3"
                    # CX16 SAHF FXSR HLE RDSEED
                    "broadwell"
                  ];
                  keepOutputs = true;
                };
                nixpkgs = { march = "alderlake"; cudaSupport = true; };
                gui = { enable = true; preferred = true; };
                kernel =
                {
                  patches = [ "cjktty" "preempt" ];
                  modules.modprobeConfig = [ "options iwlmvm power_scheme=1" "options iwlwifi uapsd_disable=1" ];
                };
                impermanence.enable = true;
                networking =
                  { hostname = "pc"; nebula = { enable = true; lighthouse = "vps6.chn.moe"; useRelay = true; }; };
                sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
              };
              hardware =
              {
                cpus = [ "intel" ];
                gpus = [ "intel" "nvidia" ];
                bluetooth.enable = true;
                joystick.enable = true;
                printer.enable = true;
                sound.enable = true;
                prime =
                  { enable = true; mode = "offload"; busId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; };};
                gamemode.drmDevice = 1;
              };
              packages =
              {
                packageSet = "workstation";
                extraPrebuildPackages = with inputs.pkgs; [ llvmPackages_git.stdenv ];
                extraPythonPackages = [(pythonPackages:
                  [ inputs.pkgs.localPackages.upho inputs.pkgs.localPackages.spectral ])];
              };
              virtualization =
              {
                waydroid.enable = true;
                docker.enable = true;
                kvmHost = { enable = true; gui = true; autoSuspend = [ "win10" "hardconnect" ]; };
                # kvmGuest.enable = true;
                nspawn = [ "arch" "ubuntu-22.04" "fedora" ];
              };
              services =
              {
                snapper = { enable = true; configs.persistent = "/nix/persistent"; };
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
                xrayClient =
                {
                  enable = true;
                  serverAddress = "74.211.99.69";
                  serverName = "vps6.xserver.chn.moe";
                  dns =
                  {
                    extraInterfaces = [ "docker0" ];
                    hosts =
                    {
                      "mirism.one" = "216.24.188.24";
                      "beta.mirism.one" = "216.24.188.24";
                      "ng01.mirism.one" = "216.24.188.24";
                      "debug.mirism.one" = "127.0.0.1";
                      "initrd.vps6.chn.moe" = "74.211.99.69";
                      "nix-store.chn.moe" = "127.0.0.1";
                      "initrd.nas.chn.moe" = "192.168.1.185";
                    };
                  };
                };
                firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
                acme = { enable = true; certs = [ "debug.mirism.one" ]; };
                frpClient =
                {
                  enable = true;
                  serverName = "frp.chn.moe";
                  user = "pc";
                  tcp.store = { localPort = 443; remotePort = 7676; };
                };
                nix-serve = { enable = true; hostname = "nix-store.chn.moe"; };
                smartd.enable = true;
                nginx =
                {
                  enable = true;
                  transparentProxy.externalIp = [ "192.168.82.3" ];
                  applications.misskey.instances."xn--qbtm095lrg0bfka60z.chn.moe" = {};
                };
                misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
                beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 2048; }; };
              };
              bugs =
              [
                "intel-hdmi" "suspend-hibernate-no-platform" "hibernate-iwlwifi" "suspend-lid-no-wakeup" "xmunet"
                "suspend-hibernate-waydroid" "embree" "nvme"
              ];
            };})
          ];
          "vps6" = 
          [
            (inputs: { config.nixos =
            {
              system =
              {
                fileSystems =
                {
                  mount =
                  {
                    btrfs =
                    {
                      "/dev/disk/by-uuid/24577c0e-d56b-45ba-8b36-95a848228600"."/boot" = "/boot";
                      "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
                    };
                  };
                  decrypt.manual =
                  {
                    enable = true;
                    devices."/dev/disk/by-uuid/4f8aca22-9ec6-4fad-b21a-fd9d8d0514e8" = { mapper = "root"; ssd = true; };
                    delayedMount = [ "/" ];
                  };
                  swap = [ "/nix/swap/swap" ];
                  rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
                };
                grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
                nixpkgs.march = "sandybridge";
                nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                initrd =
                {
                  network.enable = true;
                  sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
                };
                kernel.patches = [ "preempt" ];
                impermanence.enable = true;
                networking = { hostname = "vps6"; nebula.enable = true; };
                sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
              };
              packages.packageSet = "server";
              services =
              {
                snapper = { enable = true; configs.persistent = "/nix/persistent"; };
                sshd.enable = true;
                xrayServer = { enable = true; serverName = "vps6.xserver.chn.moe"; };
                frpServer = { enable = true; serverName = "frp.chn.moe"; };
                nginx =
                {
                  enable = true;
                  transparentProxy =
                  {
                    externalIp = [ "74.211.99.69" "192.168.82.1" ];
                    map =
                    {
                      "ng01.mirism.one" = 7411;
                      "beta.mirism.one" = 9114;
                    };
                  };
                  streamProxy =
                  {
                    enable = true;
                    map =
                    {
                      "nix-store.chn.moe" = { upstream = "internal.pc.chn.moe:443"; rewriteHttps = true; };
                      "anchor.fm" = { upstream = "anchor.fm:443"; rewriteHttps = true; };
                      "podcasters.spotify.com" = { upstream = "podcasters.spotify.com:443"; rewriteHttps = true; };
                    };
                  };
                  applications =
                  {
                    misskey.instances =
                    {
                      "xn--qbtm095lrg0bfka60z.chn.moe".upstream.address = "internal.pc.chn.moe";
                      "xn--s8w913fdga.chn.moe".upstream.address = "internal.vps7.chn.moe";
                      "misskey.chn.moe".upstream = "internal.vps7.chn.moe:9727";
                    };
                    synapse.instances."synapse.chn.moe".upstream.address = "internal.vps7.chn.moe";
                    vaultwarden = { enable = true; upstream.address = "internal.vps7.chn.moe"; };
                    element.instances."element.chn.moe" = {};
                    photoprism.instances."photoprism.chn.moe".upstream.address = "internal.vps7.chn.moe";
                    nextcloud.proxy = { enable = true; upstream = "internal.vps7.chn.moe"; };
                  };
                };
                coturn.enable = true;
                beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 16; }; };
              };
            };})
          ];
          "vps7" =
          [
            (inputs: { config.nixos =
            {
              system =
              {
                fileSystems =
                {
                  mount =
                  {
                    btrfs =
                    {
                      "/dev/disk/by-uuid/e36287f7-7321-45fa-ba1e-d126717a65f0"."/boot" = "/boot";
                      "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
                    };
                  };
                  decrypt.manual =
                  {
                    enable = true;
                    devices."/dev/disk/by-uuid/db48c8de-bcf7-43ae-a977-60c4f390d5c4" = { mapper = "root"; ssd = true; };
                    delayedMount = [ "/" ];
                  };
                  swap = [ "/nix/swap/swap" ];
                  rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
                };
                grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
                nixpkgs.march = "broadwell";
                nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                initrd =
                {
                  network.enable = true;
                  sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
                };
                kernel.patches = [ "preempt" ];
                impermanence.enable = true;
                networking = { hostname = "vps7"; nebula = { enable = true; lighthouse = "vps6.chn.moe"; }; };
                sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
                gui.enable = true;
              };
              packages =
              {
                packageSet = "desktop";
              };
              services =
              {
                snapper = { enable = true; configs.persistent = "/nix/persistent"; };
                fontconfig.enable = true;
                sshd.enable = true;
                rsshub.enable = true;
                nginx =
                {
                  enable = true;
                  transparentProxy.externalIp = [ "95.111.228.40" "192.168.82.2" ];
                  applications =
                  {
                    misskey.instances =
                    {
                      "xn--s8w913fdga.chn.moe" = {};
                      "misskey.chn.moe".upstream.port = 9727;
                    };
                    synapse.instances."synapse.chn.moe" = {};
                    vaultwarden.enable = true;
                    photoprism.instances."photoprism.chn.moe" = {};
                    nextcloud.instance.enable = true;
                  };
                };
                wallabag.enable = true;
                misskey.instances =
                {
                  misskey.hostname = "xn--s8w913fdga.chn.moe";
                  misskey-old = { port = 9727; redis.port = 3546; meilisearch.enable = false; };
                };
                synapse.enable = true;
                xrdp = { enable = true; hostname = "vps7.chn.moe"; };
                vaultwarden.enable = true;
                meilisearch.ioLimitDevice = "/dev/mapper/root";
                beesd = { enable = false; instances.root = { device = "/"; hashTableSizeMB = 1024; }; };
                photoprism.enable = true;
                nextcloud.enable = true;
              };
            };})
          ];
          "nas" =
          [
            (inputs: { config.nixos =
            {
              system =
              {
                fileSystems =
                {
                  mount =
                  {
                    vfat."/dev/disk/by-uuid/13BC-F0C9" = "/boot/efi";
                    btrfs =
                    {
                      "/dev/disk/by-uuid/0e184f3b-af6c-4f5d-926a-2559f2dc3063"."/boot" = "/boot";
                      "/dev/mapper/nix"."/nix" = "/nix";
                      "/dev/mapper/root1" =
                      {
                        "/nix/rootfs" = "/nix/rootfs";
                        "/nix/persistent" = "/nix/persistent";
                        "/nix/nodatacow" = "/nix/nodatacow";
                        "/nix/rootfs/current" = "/";
                      };
                    };
                  };
                  decrypt.manual =
                  {
                    enable = true;
                    devices =
                    {
                      "/dev/disk/by-uuid/5cf1d19d-b4a5-4e67-8e10-f63f0d5bb649".mapper = "root1";
                      "/dev/disk/by-uuid/aa684baf-fd8a-459c-99ba-11eb7636cb0d".mapper = "root2";
                      "/dev/disk/by-uuid/a779198f-cce9-4c3d-a64a-9ec45f6f5495" = { mapper = "nix"; ssd = true; };
                    };
                    delayedMount = [ "/" "/nix" ];
                  };
                  rollingRootfs = { device = "/dev/mapper/root1"; path = "/nix/rootfs"; };
                };
                initrd =
                {
                  network.enable = true;
                  sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
                };
                grub.installDevice = "efi";
                nixpkgs.march = "silvermont";
                nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                kernel.patches = [ "cjktty" "preempt" ];
                impermanence.enable = true;
                networking =
                  { hostname = "nas"; nebula = { enable = true; lighthouse = "vps6.chn.moe"; useRelay = true; }; };
                sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
                gui.enable = true;
              };
              hardware =
              {
                cpus = [ "intel" ];
                gpus = [ "intel" ];
              };
              packages.packageSet = "desktop";
              services =
              {
                snapper = { enable = false; configs.persistent = "/nix/persistent"; };
                fontconfig.enable = true;
                samba =
                {
                  enable = true;
                  hostsAllowed = "192.168. 127.";
                  shares =
                  {
                    home.path = "/home";
                    root.path = "/";
                  };
                };
                sshd = { enable = true; passwordAuthentication = true; };
                xrayClient =
                {
                  enable = true;
                  serverAddress = "74.211.99.69";
                  serverName = "vps6.xserver.chn.moe";
                  dns.extraInterfaces = [ "docker0" ];
                };
                xrdp = { enable = true; hostname = [ "nas.chn.moe" "office.chn.moe" ]; };
                groupshare.enable = true;
                smartd.enable = true;
                beesd =
                {
                  enable = false;
                  instances =
                  {
                    root = { device = "/"; hashTableSizeMB = 2048; };
                    nix = { device = "/nix"; hashTableSizeMB = 128; };
                  };
                };
              };
              users.users = [ "root" "chn" "xll" "zem" "yjq" "yxy" ];
            };})
          ];
          "xmupc1" =
          [
            (inputs: { config.nixos =
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
                    "/dev/md/swap" = { mapper = "swap"; ssd = true; before = [ "root" ]; };
                  };
                  mdadm =
                    "ARRAY /dev/md/swap metadata=1.2 name=pc:swap UUID=2b546b8d:e38007c8:02990dd1:df9e23a4";
                  swap = [ "/dev/mapper/swap" ];
                  resume = "/dev/mapper/swap";
                  rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
                };
                grub.installDevice = "efi";
                nixpkgs = { march = "znver3"; cudaSupport = true; };
                nix =
                {
                  marches =
                  [
                    "znver3" "znver2"
                    # PREFETCHW RDRND XSAVE XSAVEOPT PTWRITE SGX GFNI-SSE MOVDIRI MOVDIR64B CLDEMOTE WAITPKG LZCNT
                    # PCONFIG SERIALIZE HRESET KL WIDEKL AVX-VNNI
                    "alderlake"
                    # SAHF FXSR XSAVE
                    "sandybridge"
                    # SAHF FXSR PREFETCHW RDRND
                    "silvermont"
                  ];
                  substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                };
                gui.enable = true;
                kernel =
                {
                  patches = [ "cjktty" "preempt" ];
                  modules.modprobeConfig = [ "options iwlmvm power_scheme=1" "options iwlwifi uapsd_disable=1" ];
                };
                impermanence.enable = true;
                networking.hostname = "xmupc1";
                sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
              };
              hardware =
              {
                cpus = [ "intel" ];
                gpus = [ "intel" "nvidia" ];
                bluetooth.enable = true;
                joystick.enable = true;
                printer.enable = true;
                sound.enable = true;
                prime =
                  { enable = true; mode = "offload"; busId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; };};
              };
              packages.packageSet = "workstation";
              virtualization =
              {
                docker.enable = true;
                kvmHost = { enable = true; gui = true; };
              };
              services =
              {
                snapper = { enable = true; configs.persistent = "/nix/persistent"; };
                fontconfig.enable = true;
                samba =
                {
                  enable = true;
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
                xrayClient =
                {
                  enable = true;
                  serverAddress = "74.211.99.69";
                  serverName = "vps6.xserver.chn.moe";
                  dns =
                  {
                    extraInterfaces = [ "docker0" ];
                    hosts =
                    {
                      "mirism.one" = "216.24.188.24";
                      "beta.mirism.one" = "216.24.188.24";
                      "ng01.mirism.one" = "216.24.188.24";
                      "debug.mirism.one" = "127.0.0.1";
                      "initrd.vps6.chn.moe" = "74.211.99.69";
                      "nix-store.chn.moe" = "127.0.0.1";
                    };
                  };
                };
                firewall.trustedInterfaces = [ "virbr0" ];
                frpClient =
                {
                  enable = true;
                  serverName = "frp.chn.moe";
                  user = "xmupc1";
                  tcp.store = { localPort = 443; remotePort = 7676; };
                };
                smartd.enable = true;
                nginx = { enable = true; transparentProxy.enable = false; };
                postgresql.enable = true;
              };
              bugs = [ "xmunet" "firefox" "embree" ];
            };})
          ];
          "yoga" =
          [
            (inputs: { config.nixos =
            {
              system =
              {
                fileSystems =
                {
                  mount =
                  {
                    vfat."/dev/disk/by-uuid/86B8-CF80" = "/boot/efi";
                    btrfs =
                    {
                      "/dev/disk/by-uuid/e252f81d-b4b3-479f-8664-380a9b73cf83"."/boot" = "/boot";
                      "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
                    };
                  };
                  decrypt.auto."/dev/disk/by-uuid/8186d34e-005c-4461-94c7-1003a5bd86c0" =
                    { mapper = "root"; ssd = true; };
                  swap = [ "/nix/swap/swap" ];
                  rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
                };
                nixpkgs.march = "silvermont";
                gui.enable = true;
                grub.installDevice = "efi";
                nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                kernel.patches = [ "cjktty" "preempt" ];
                impermanence.enable = true;
                networking.hostname = "yoga";
                sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
              };
              hardware =
              {
                cpus = [ "intel" ];
                gpus = [ "intel" ];
                bluetooth.enable = true;
                joystick.enable = true;
                printer.enable = true;
                sound.enable = true;
              };
              packages.packageSet = "desktop";
              virtualization.docker.enable = true;
              services =
              {
                snapper = { enable = true; configs.persistent = "/nix/persistent"; };
                fontconfig.enable = true;
                sshd.enable = true;
                xrayClient =
                {
                  enable = true;
                  serverAddress = "74.211.99.69";
                  serverName = "vps6.xserver.chn.moe";
                  dns.extraInterfaces = [ "docker0" ];
                };
                firewall.trustedInterfaces = [ "virbr0" ];
                smartd.enable = true;
              };
            };})
          ];
        }));
      # sudo HTTPS_PROXY=socks5://127.0.0.1:10884 nixos-install --flake .#bootstrap --option substituters http://127.0.0.1:5000 --option require-sigs false --option system-features gccarch-silvermont
      # nix-serve -p 5000
      # nix copy --substitute-on-destination --to ssh://server /run/current-system
      # nix copy --to ssh://nixos@192.168.122.56 ./result
      # sudo nixos-install --flake .#bootstrap
      #    --option substituters http://192.168.122.1:5000 --option require-sigs false
      # sudo chattr -i var/empty
      # nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
      # sudo nixos-rebuild switch --flake .#vps6 --log-format internal-json -v |& nom --json
      # boot.shell_on_fail systemd.setenv=SYSTEMD_SULOGIN_FORCE=1
      # sudo usbipd
      # ssh -R 3240:127.0.0.1:3240 root@192.168.122.57
      # modprobe vhci-hcd
      # sudo usbip bind -b 3-6
      # usbip attach -r 127.0.0.1 -b 3-6
      # systemd-cryptenroll --fido2-device=auto /dev/vda2
      # systemd-cryptsetup attach root /dev/vda2
      deploy =
      {
        sshUser = "root";
        user = "root";
        fastConnection = true;
        autoRollback = false;
        magicRollback = false;
        nodes = builtins.listToAttrs (builtins.map
          (node:
          {
            name = node;
            value =
            {
              hostname = node;
              profiles.system.path = inputs.self.nixosConfigurations.${node}.pkgs.deploy-rs.lib.activate.nixos
                  inputs.self.nixosConfigurations.${node};
            };
          })
          [ "vps6" "vps7" "nas" ]);
      };
    };
}
