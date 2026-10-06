{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = {
    boot = {
      # allow non-root users to access intel gpu performance counters
      kernel.sysctl."dev.i915.perf_stream_paranoid" = false;
    };
    security = {
      pam = {
        u2f = {
          enable = true;
          settings = {
            cue = true;
            appid = "pam://chn.moe";
            origin = "pam://chn.moe";
            # generate using: `pamu2fcfg -u chn -o pam://chn.moe -i pam://chn.moe`
            authfile = builtins.toString (
              pkgs.writeText "u2f_mappings" (
                let
                  key = builtins.concatStringsSep "," [
                    "83Y3cLxhcmwbDOH1h67SQ1xy0dFBcoKYM0VO/YVq+9lpOpdPdmFaB7BNngO3xCmAxJeO/Fg9jNmEF9vMJEmAaw=="
                    "9bSjr+12JVwtHlyoa70J7w3bEQff+MwLxg5elzdP1OGHcfWGkolRvS+luAgcWjKn1g0swaYdnklCYWYOoCAJbA=="
                    "es256"
                    "+presence"
                  ];
                  users = [
                    "chn"
                    "root"
                    "straycat"
                  ];
                in
                builtins.concatStringsSep "\n" (map (u: "${u}:${key}") users)
              )
            );
          };
        };
        yubico = {
          enable = true;
          id = "91291";
        };
        rssh.enable = true;
        services =
          let
            u2fOrder = s: config.security.pam.services.${s}.rules.auth.u2f.order;
            yubicoMappings = builtins.toString (
              pkgs.writeText "yubico_mappings" (
                let
                  yubicoId = "cccccbgrhnub";
                  users = [
                    "chn"
                    "root"
                    "straycat"
                  ];
                in
                builtins.concatStringsSep "\n" (map (u: "${u}:${yubicoId}") users)
              )
            );
          in
          {
            sudo = {
              rssh = true;
              rules.auth.rssh.order = (u2fOrder "sudo") + 10;
              rules.auth.yubico.order = (u2fOrder "sudo") + 20;
              rules.auth.yubico.settings.authfile = yubicoMappings;
            };
            su = {
              rssh = true;
              rules.auth.rssh.order = (u2fOrder "su") + 10;
              rules.auth.yubico.order = (u2fOrder "su") + 20;
              rules.auth.yubico.settings.authfile = yubicoMappings;
            };
            login = {
              rules.auth.yubico.order = (u2fOrder "login") + 10;
              rules.auth.yubico.settings.authfile = yubicoMappings;
            };
            # PAM service for nginx's auth_pam, used only by omp-web (see
            # nixosConfigurations/nas/omp-web.nix). Defined here rather than in that
            # host because yubicoMappings only exists in this scope.
            "nginx-omp" = {
              # The nginx worker runs with PrivateDevices=yes and DevicePolicy=closed,
              # so it has no /dev/hidraw* and u2f can never work: keep it out of the stack
              # instead of leaving a module that only ever fails.
              u2f.enable = false;
              rules = {
                # Only the user owning the omp sessions may log in.
                auth.restrict-user = {
                  order = config.security.pam.services."nginx-omp".rules.auth.unix.order - 1000;
                  control = "requisite";
                  modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
                  args = [
                    "user"
                    "="
                    "straycat"
                  ];
                };
                account.restrict-user = {
                  order = config.security.pam.services."nginx-omp".rules.account.unix.order - 1000;
                  control = "requisite";
                  modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
                  args = [
                    "user"
                    "="
                    "straycat"
                  ];
                };
                # The yubico rule itself is injected by nixpkgs (security.pam.yubico.enable),
                # with `control = sufficient` and `id`. Only the key mapping has to be passed
                # explicitly: nginx runs with ProtectHome=yes, so pam_yubico cannot fall back
                # to reading ~/.yubico/authorized_yubikeys.
                auth.yubico.settings.authfile = yubicoMappings;
              };
            };
          };
        loginLimits = [
          {
            domain = "@users";
            item = "nofile";
            value = 524288;
          }
          # do not set stack to unlimited as default, some applications (e.g. wine) will fail
          # { domain = "@users"; item = "stack"; value = "unlimited"; }
        ];
      };
      sudo.extraConfig = "Defaults pwfeedback";
    };
    systemd = {
      user.extraConfig = "DefaultLimitNOFILE=524288:524288";
      tmpfiles.settings."10-pcscd"."/run/pcscd".d.mode = "0755";
    };
    # needed by xray tproxy if we want to forward traffic from other machine
    networking.firewall.checkReversePath = false;
    # this file is needed by p11tool and systemd-cryptenroll to detect opensc lib
    environment.etc."pkcs11/modules/opensc.module".text = ''
      module: ${pkgs.opensc}/lib/opensc-pkcs11.so
      managed: yes
    '';
    # only enable on desktop, use socket forwarding on server
    services.pcscd.enable = lib.mkIf (config.nixos.model.variant == "desktop") true;
  };
}
