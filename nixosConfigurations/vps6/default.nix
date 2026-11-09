{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = lib.findModules ./.;
  config = {
    nixos = {
      system = {
        fileSystems = {
          mount = {
            btrfs = {
              "/dev/disk/by-uuid/0067ef91-06f7-416e-88cb-4880ce04afa4"."/boot" = "/boot";
              "/dev/mapper/root" = {
                "/nix" = "/nix";
                "/nix/rootfs/current" = "/";
              };
            };
          };
          swap = [ "/nix/swap/swap" ];
          luks.devices."/dev/disk/by-uuid/961d75f0-b4ad-4591-a225-37b385131060" = {
            mapper = "root";
            ssd = true;
          };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        initrd.sshd = { };
        network.settings.dhcp = [ "ens18" ];
      };
      services = {
        sshd = { };
        nginx.applications = {
          element = { };
          synapse-admin = { };
          catalog = { };
          main = { };
          nekomia = { };
          blog = { };
          sticker = { };
          tgapi = { };
          short = { };
        };
        nginx.https."aidesk.chn.moe" = {
          global.extraConfig = ''
            # index.html, sw.js and manifest.webmanifest are unhashed entry
            # points: always revalidate, so the next load after a deploy gets
            # the new build instead of a stale entry point. The hashed files in
            # the /assets/ location override this with a long cache.
            add_header Cache-Control "no-cache";
          '';
          location = {
            # Public, unauthenticated SPA; the API on api.aidesk.chn.moe is
            # stream-proxied to nas and guarded by Authelia there.
            "/".static = {
              root = "${pkgs.localPkgs.aidesk.frontend}";
              tryFiles = [
                "$uri"
                "$uri/"
                "/index.html"
              ];
            };
            # vite content-hashes everything in here. A stale page asking for
            # a chunk of the previous build must get a real 404: falling back
            # to index.html answers 200 text/html and makes the dynamic
            # import() fail with a MIME type error, which blanks the app.
            "/assets/".static = {
              root = "${pkgs.localPkgs.aidesk.frontend}";
              tryFiles = [
                "$uri"
                "=404"
              ];
            };
            # AIDesk 网盘助手 (mount-wizard) download linked from Settings →
            # Add-ons. The package installs the single self-contained
            # executable at `bin/aidesk-mount-wizard.exe`, so the SPA links to
            # /bin/aidesk-mount-wizard.exe. nginx's stock `mime.types` maps
            # `.exe` to application/octet-stream, which browsers download
            # rather than render.
            "/bin/".static = {
              root = "${pkgs.localPkgs.aidesk.mount-wizard}";
              tryFiles = [
                "$uri"
                "=404"
              ];
            };
          };
        };
        coturn = { };
        httpua = { };
        mirism = { };
        fail2ban = { };
        beesd."/" = { };
        hongbao = { };
        freshman-followup.hostname = "hf.chn.moe";
        cliproxyapi.users = [
          "southfox"
          "alikia"
          "cclin"
        ];
      };
    };
    # The https module has no per-location extraConfig for static roots, so the
    # immutable cache header is attached to the generated location here.
    services.nginx.virtualHosts."https:aidesk.chn.moe".locations."/assets/".extraConfig = ''
      add_header Cache-Control "public, max-age=31536000, immutable";
    '';
    networking.nftables.tables.forward = {
      family = "inet";
      content =
        let
          srv2 = pkgs.localPkgs.getAddress "tinc0.srv2-node0";
          pc = pkgs.localPkgs.getAddress "tinc0.pc";
        in
        ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            tcp dport 7011 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
            tcp dport 7012 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${pc}:22
          }
          chain output {
            type nat hook output priority dstnat; policy accept;
            # 需要忽略透明代理发出的流量（gid 不是 nginx）
            meta skgid != ${builtins.toString config.users.groups.nginx.gid} \
              tcp dport 7011 fib daddr type local \
              counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
            meta skgid != ${builtins.toString config.users.groups.nginx.gid} \
              tcp dport 7012 fib daddr type local \
              counter meta mark set meta mark | 4 dnat ip to ${pc}:22
          }
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname tinc0 meta mark & 4 == 4 counter masquerade
          }
        '';
    };
  };
}
