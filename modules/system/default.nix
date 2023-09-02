inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./nix.nix
    ./fileSystems.nix
    ./grub.nix
  ];
  options.nixos.system = let inherit (inputs.lib) mkOption types; in
  {
    hostname = mkOption { type = types.nonEmptyStr; };
    march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    gui.enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf mkAfter;
      inherit (inputs.localLib) mkConditional stripeTabs;
      inherit (inputs.config.nixos) system;
    in
      mkMerge
      [
        # generic
        {
          services =
          {
            udev.extraRules =
            ''
              ACTION=="add|change", KERNEL=="[sv]d[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
              ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
            '';
            dbus.implementation = "broker";
            journald.extraConfig = "MaxRetentionSec=7d";
          };
          networking.networkmanager =
          {
            enable = true;
            extraConfig =
            ''
              [device]
              keep-configuration=no
            '';
          };
          nixpkgs =
          {
            config.allowUnfree = true;
            overlays = [(final: prev: { genericPackages = (inputs.topInputs.nixpkgs.lib.nixosSystem
            {
              system = "x86_64-linux";
              modules = [{ config.nixpkgs.config.allowUnfree = true; }];
            }).pkgs;})];
          };
          time.timeZone = "Asia/Shanghai";
          boot =
          {
            kernel.sysctl =
            {
              "net.core.rmem_max" = 67108864;
              "net.core.wmem_max" = 67108864;
              "net.ipv4.tcp_rmem" = "4096 87380 67108864";
              "net.ipv4.tcp_wmem" = "4096 65536 67108864";
              "net.ipv4.tcp_mtu_probing" = true;
              "net.ipv4.tcp_tw_reuse" = true;
              "vm.swappiness" = 10;
              "net.ipv4.tcp_max_syn_backlog" = 8388608;
              "net.core.netdev_max_backlog" = 8388608;
              "net.core.somaxconn" = 8388608;
              "vm.oom_kill_allocating_task" = true;
              "vm.oom_dump_tasks" = false;
              "vm.overcommit_memory" = 1;
              "dev.i915.perf_stream_paranoid" = false;
              "net.ipv4.conf.all.route_localnet" = true;
              "net.ipv4.conf.default.route_localnet" = true;
              "net.ipv4.conf.all.accept_local" = true;
              "net.ipv4.conf.default.accept_local" = true;
              "net.ipv4.ip_forward" = true;
              "net.ipv4.ip_nonlocal_bind" = true;
              "net.bridge.bridge-nf-call-iptables" = false;
              "net.bridge.bridge-nf-call-ip6tables" = false;
              "net.bridge.bridge-nf-call-arptables" = false;
            };
            supportedFilesystems = [ "ntfs" ];
            consoleLogLevel = 7;
          };
          hardware.enableAllFirmware = true;
          systemd =
          {
            extraConfig =
            ''
              DefaultTimeoutStopSec=10s
              DefaultLimitNOFILE=1048576:1048576
            '';
            user.extraConfig = "DefaultTimeoutStopSec=10s";
            services.systemd-tmpfiles-setup = { environment = { SYSTEMD_TMPFILES_FORCE_SUBVOL = "0"; }; };
            timers.systemd-tmpfiles-clean.enable = false;
            coredump.enable = false;
          };
          environment =
          {
            sessionVariables = rec
            {
              XDG_CACHE_HOME = "$HOME/.cache";
              XDG_CONFIG_HOME = "$HOME/.config";
              XDG_DATA_HOME = "$HOME/.local/share";
              XDG_STATE_HOME = "$HOME/.local/state";
              # ANDROID_HOME = "${XDG_DATA_HOME}/android";
              HISTFILE= "${XDG_STATE_HOME}/bash/history";
              CUDA_CACHE_PATH = "${XDG_CACHE_HOME}/nv";
              DOCKER_CONFIG = "${XDG_CONFIG_HOME}/docker";
              GNUPGHOME = "${XDG_DATA_HOME}/gnupg";
              GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc";
              XCOMPOSECACHE = "${XDG_CACHE_HOME}/X11/xcompose";
              MATHEMATICA_USERBASE = "${XDG_CONFIG_HOME}/mathematica";
              _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${XDG_CONFIG_HOME}/java";
            };
          };
          i18n =
          {
            defaultLocale = "C.UTF-8";
            supportedLocales = [ "zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8" ];
          };
          # environment.pathsToLink = [ "/include" ];
          # environment.variables.CPATH = "/run/current-system/sw/include";
          # environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
          security.pam =
          {
            u2f =
            {
              enable = true;
              cue = true;
              appId = "pam://chn.moe";
              origin = "pam://chn.moe";
              # generate using `pamu2fcfg -u chn -o pam://chn.moe -i pam://chn.moe`
              authFile = inputs.pkgs.writeText "yubikey_mappings" (builtins.concatStringsSep "\n"
              [
                (builtins.concatStringsSep ":"
                [
                  "chn"
                  (builtins.concatStringsSep ","
                  [
                    "83Y3cLxhcmwbDOH1h67SQ1xy0dFBcoKYM0VO/YVq+9lpOpdPdmFaB7BNngO3xCmAxJeO/Fg9jNmEF9vMJEmAaw=="
                    "9bSjr+12JVwtHlyoa70J7w3bEQff+MwLxg5elzdP1OGHcfWGkolRvS+luAgcWjKn1g0swaYdnklCYWYOoCAJbA=="
                    "es256"
                    "+presence"
                  ])
                  (builtins.concatStringsSep ","
                  [
                    "WgLCnlQcGP4uVHI8OZrJWoLK6ezHtl404NVGsfH2LXsq0TNVZ7l2OidGpbYqIJwTn5yKu6t0MI7KdHYD18T/HA=="
                    "GVPuwp38yb+A1Uur22hywW7mQJPOxuLXXKLlM9FU2bvVhpwdjWDvg+BB5YFAL9NjTW22V7Hy/a9UuSmZejs7dw=="
                    "es256"
                    "+presence"
                  ])
                ])
              ]);
            };
            yubico =
            {
              enable = true;
              id = "91291";
              authFile = inputs.pkgs.writeText "yubikey_mappings" "chn:cccccbgrhnub";
            };
          };
          virtualisation.oci-containers.backend = "docker";
        }
        # hostname
        { networking.hostName = system.hostname; }
        # march
        (
          mkConditional (system.march != null)
            {
              nixpkgs =
              {
                hostPlatform = { system = "x86_64-linux"; gcc = { arch = system.march; tune = system.march; }; };
                config.qchem-config.optArch = system.march;
              };
              boot.kernelPatches =
              [{
                name = "native kernel";
                patch = null;
                extraStructuredConfig =
                  let
                    kernelConfig =
                    {
                      alderlake = "MALDERLAKE";
                      sandybridge = "MSANDYBRIDGE";
                      silvermont = "MSILVERMONT";
                      broadwell = "MBROADWELL";
                      znver2 = "MZEN2";
                      znver3 = "MZEN3";
                    };
                  in
                  {
                    GENERIC_CPU = inputs.lib.kernel.no;
                    ${kernelConfig.${system.march}} = inputs.lib.kernel.yes;
                  };
              }];
            }
            { nixpkgs.hostPlatform = inputs.lib.mkDefault "x86_64-linux"; }
        )
        # gui.enable
        (mkIf inputs.config.nixos.system.gui.enable
        {
            services.xserver =
            {
              enable = true;
              displayManager = { sddm.enable = true; defaultSession = "plasmawayland"; };
              desktopManager.plasma5.enable = true;
              videoDrivers = inputs.config.nixos.hardware.gpus;
            };
            systemd.services.display-manager.after = [ "network-online.target" ];
            environment.sessionVariables."GTK_USE_PORTAL" = "1";
            xdg.portal.extraPortals = with inputs.pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
            i18n.inputMethod =
            {
              enabled = "fcitx5";
              fcitx5.addons = with inputs.pkgs; [ fcitx5-rime fcitx5-chinese-addons fcitx5-mozc ];
            };
            programs =
            {
              dconf.enable = true;
              xwayland.enable = true;
            };
        })
      ];
}
