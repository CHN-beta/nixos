{
  description = "CNH's NixOS Flake";

  inputs =
  {
    nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:CHN-beta/nixpkgs/nixos-unstable";
    nixpkgs-2305.url = "github:CHN-beta/nixpkgs/nixos-23.05";
    home-manager = { url = "github:nix-community/home-manager/release-23.11"; inputs.nixpkgs.follows = "nixpkgs"; };
    sops-nix =
    {
      url = "github:Mic92/sops-nix";
      inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs"; };
    };
    aagl = { url = "github:ezKEa/aagl-gtk-on-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur.url = "github:nix-community/NUR";
    nixos-cn = { url = "github:nixos-cn/flakes"; inputs.nixpkgs.follows = "nixpkgs"; };
    nur-xddxdd = { url = "github:xddxdd/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-alien =
    {
      url = "github:thiagokokada/nix-alien";
      inputs = { nixpkgs.follows = "nixpkgs"; nix-index-database.follows = "nix-index-database"; };
    };
    impermanence.url = "github:nix-community/impermanence";
    qchem = { url = "github:Nix-QChem/NixOS-QChem"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixd = { url = "github:nix-community/nixd"; inputs.nixpkgs.follows = "nixpkgs"; };
    napalm = { url = "github:nix-community/napalm"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixpak = { url = "github:nixpak/nixpak"; inputs.nixpkgs.follows = "nixpkgs"; };
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
    pnpm2nix-nzbr = { url = "github:CHN-beta/pnpm2nix-nzbr"; inputs.nixpkgs.follows = "nixpkgs"; };
    lmix = { url = "github:CHN-beta/lmix"; inputs.nixpkgs.follows = "nixpkgs"; };
    dguibert-nur-packages = { url = "github:CHN-beta/dguibert-nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
    plasma-manager =
    {
      url = "github:pjones/plasma-manager";
      inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
    };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; inputs.nixpkgs.follows = "nixpkgs"; };
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
            [ "pc" "vps6" "vps7" "nas" "yoga" ]));
      }
      // (
        builtins.listToAttrs (builtins.map
          (system:
          {
            name = system;
            value = inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel;
          })
          [ "pc" "vps6" "vps7" "nas" "yoga" "xmupc1" ])
      );
      # ssh-keygen -t rsa -C root@pe -f /mnt/nix/persistent/etc/ssh/ssh_host_rsa_key
      # ssh-keygen -t ed25519 -C root@pe -f /mnt/nix/persistent/etc/ssh/ssh_host_ed25519_key
      # systemd-machine-id-setup --root=/mnt/nix/persistent
      nixosConfigurations =
        let
          system =
          {
            pc =
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
                nixpkgs =
                  { march = "alderlake"; cuda = { enable = true; capabilities = [ "8.6" ]; forwardCompat = false; }; };
                kernel.patches = [ "cjktty" ];
                impermanence.enable = true;
                networking.hostname = "pc";
              };
              hardware =
              {
                cpus = [ "intel" ];
                gpus = [ "intel" "nvidia" ];
                bluetooth.enable = true;
                joystick.enable = true;
                printer.enable = true;
                sound.enable = true;
                prime = { enable = true; mode = "offload"; busId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; }; };
                gamemode.drmDevice = 1;
              };
              packages.packageSet = "workstation";
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
                beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 2048; }; };
                wireguard =
                {
                  enable = true;
                  peers = [ "vps6" ];
                  publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
                  wireguardIp = "192.168.83.3";
                };
              };
              bugs =
              [
                "intel-hdmi" "suspend-hibernate-no-platform" "hibernate-iwlwifi" "suspend-lid-no-wakeup" "xmunet"
                "suspend-hibernate-waydroid"
              ];
            };
            vps6 =
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
                initrd.sshd.enable = true;
                impermanence.enable = true;
                networking.hostname = "vps6";
              };
              packages.packageSet = "server";
              services =
              {
                snapper.enable = true;
                sshd.enable = true;
                xrayServer = { enable = true; serverName = "vps6.xserver.chn.moe"; };
                frpServer = { enable = true; serverName = "frp.chn.moe"; };
                nginx =
                {
                  streamProxy.map =
                  {
                    "anchor.fm" = { upstream = "anchor.fm:443"; proxyProtocol = false; };
                    "podcasters.spotify.com" = { upstream = "podcasters.spotify.com:443"; proxyProtocol = false; };
                    "xlog.chn.moe" = { upstream = "cname.xlog.app:443"; proxyProtocol = false; };
                  }
                  // (builtins.listToAttrs (builtins.map
                    (site: { name = "${site}.chn.moe"; value.upstream.address = "wireguard.pc.chn.moe"; })
                    [ "nix-store" "xn--qbtm095lrg0bfka60z" ]))
                  // (builtins.listToAttrs (builtins.map
                    (site: { name = "${site}.chn.moe"; value.upstream.address = "wireguard.vps7.chn.moe"; })
                    [ "xn--s8w913fdga" "misskey" "synapse" "send" "kkmeeting" "api" "git" "grafana" ]));
                  applications =
                  {
                    element.instances."element.chn.moe" = {};
                    synapse-admin.instances."synapse-admin.chn.moe" = {};
                    catalog.enable = true;
                    blog.enable = true;
                    main.enable = true;
                  };
                };
                coturn.enable = true;
                httpua.enable = true;
                mirism.enable = true;
                fail2ban.enable = true;
                wireguard =
                {
                  enable = true;
                  peers = [ "pc" "nas" "vps7" ];
                  publicKey = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
                  wireguardIp = "192.168.83.1";
                  externalIp = "74.211.99.69";
                  lighthouse = true;
                };
              };
            };
            vps7 =
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
                initrd.sshd.enable = true;
                impermanence.enable = true;
                networking.hostname = "vps7";
                gui.preferred = false;
              };
              packages.packageSet = "desktop";
              services =
              {
                snapper.enable = true;
                fontconfig.enable = true;
                sshd.enable = true;
                rsshub.enable = true;
                wallabag.enable = true;
                misskey.instances =
                {
                  misskey.hostname = "xn--s8w913fdga.chn.moe";
                  misskey-old = { port = 9727; redis.port = 3546; meilisearch.enable = false; };
                };
                synapse.instances.synapse.matrixHostname = "synapse.chn.moe";
                xrdp = { enable = true; hostname = [ "vps7.chn.moe" ]; };
                vaultwarden.enable = true;
                beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 1024; }; };
                photoprism.enable = true;
                nextcloud.enable = true;
                freshrss.enable = true;
                send.enable = true;
                huginn.enable = true;
                fz-new-order.enable = true;
                nginx.applications = { kkmeeting.enable = true; webdav.instances."webdav.chn.moe" = {}; };
                httpapi.enable = true;
                mastodon.enable = true;
                gitea.enable = true;
                grafana.enable = true;
                fail2ban.enable = true;
                wireguard =
                {
                  enable = true;
                  peers = [ "vps6" ];
                  publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
                  wireguardIp = "192.168.83.2";
                  externalIp = "95.111.228.40";
                };
                akkoma.enable = true;
              };
            };
            nas =
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
                        "/nix/backup" = "/nix/backup";
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
                  swap = [ "/nix/swap/swap" ];
                  rollingRootfs = { device = "/dev/mapper/root1"; path = "/nix/rootfs"; };
                };
                initrd.sshd.enable = true;
                grub.installDevice = "efi";
                nixpkgs.march = "silvermont";
                nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                kernel.patches = [ "cjktty" ];
                impermanence.enable = true;
                networking.hostname = "nas";
                gui.preferred = false;
              };
              hardware = { cpus = [ "intel" ]; gpus = [ "intel" ]; };
              packages.packageSet = "desktop";
              services =
              {
                snapper.enable = true;
                fontconfig.enable = true;
                samba =
                {
                  enable = true;
                  hostsAllowed = "192.168. 127.";
                  shares = { home.path = "/home"; root.path = "/"; };
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
                  enable = true;
                  instances =
                  {
                    root = { device = "/"; hashTableSizeMB = 2048; };
                    nix = { device = "/nix"; hashTableSizeMB = 128; };
                  };
                };
                frpClient =
                {
                  enable = true;
                  serverName = "frp.chn.moe";
                  user = "nas";
                  stcp.hpc = { localIp = "hpc.xmu.edu.cn"; localPort = 22; };
                };
                nginx = { enable = true; applications.webdav.instances."local.webdav.chn.moe" = {}; };
                wireguard =
                {
                  enable = true;
                  peers = [ "vps6" ];
                  publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
                  wireguardIp = "192.168.83.4";
                };
              };
              users.users = [ "chn" "xll" "zem" "yjq" "yxy" ];
            };
            yoga =
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
                grub.installDevice = "efi";
                nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
                kernel.patches = [ "cjktty" ];
                impermanence.enable = true;
                networking.hostname = "yoga";
              };
              hardware =
              {
                cpus = [ "intel" ];
                gpus = [ "intel" ];
                bluetooth.enable = true;
                joystick.enable = true;
                printer.enable = true;
                sound.enable = true;
                halo-keyboard.enable = true;
              };
              packages.packageSet = "desktop-fat";
              virtualization.docker.enable = true;
              services =
              {
                snapper.enable = true;
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
              };
              bugs = [ "xmunet" ];
            };
            xmupc1 =
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
                  swap = [ "/dev/mapper/swap" ];
                  resume = "/dev/mapper/swap";
                  rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
                };
                grub.installDevice = "efi";
                nixpkgs =
                {
                  march = "znver3";
                  cuda =
                  {
                    enable = true;
                    capabilities =
                    [
                      # 2080 Ti
                      "7.5"
                      # 3090
                      "8.6"
                      # 4090
                      "8.9"
                    ];
                    forwardCompat = false;
                  };
                };
                gui.preferred = false;
                kernel.patches = [ "cjktty" ];
                impermanence.enable = true;
                networking.hostname = "xmupc1";
              };
              hardware =
              {
                cpus = [ "amd" ];
                gpus = [ "nvidia" ];
                bluetooth.enable = true;
                joystick.enable = true;
                printer.enable = true;
                sound.enable = true;
                gamemode.drmDevice = 1;
              };
              packages.packageSet = "workstation";
              virtualization = { docker.enable = true; kvmHost = { enable = true; gui = true; }; };
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
                xrayClient =
                {
                  enable = true;
                  serverAddress = "74.211.99.69";
                  serverName = "vps6.xserver.chn.moe";
                  dns.extraInterfaces = [ "docker0" ];
                };
                firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
                acme = { enable = true; cert."debug.mirism.one" = {}; };
                smartd.enable = true;
                beesd = { enable = true; instances.root = { device = "/nix/persistent"; hashTableSizeMB = 2048; }; };
                wireguard =
                {
                  enable = true;
                  peers = [ "vps6" ];
                  publicKey = "JEY7D4ANfTpevjXNvGDYO6aGwtBGRXsf/iwNwjwDRQk=";
                  wireguardIp = "192.168.83.5";
                };
              };
              bugs = [ "xmunet" "firefox" ];
            };
          };
        in builtins.listToAttrs (builtins.map
          (system:
          {
            name = system.name;
            value = inputs.nixpkgs.lib.nixosSystem
            {
              system = "x86_64-linux";
              specialArgs = { topInputs = inputs; inherit localLib; };
              modules = localLib.mkModules
              [
                (inputs: { config.nixpkgs.overlays = [(final: prev:
                  { localPackages = (import ./local/pkgs { inherit (inputs) lib; pkgs = final; }); })]; })
                ./modules
                { config.nixos = system.value; }
              ];
            };
          })
          (localLib.attrsToList system));
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
          [ "vps6" "vps7" "nas" "yoga" ]);
      };
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks inputs.self.deploy) inputs.deploy-rs.lib;
      overlays.default = final: prev:
        { localPackages = (import ./local/pkgs { inherit (inputs) lib; pkgs = final; }); };
    };
}
