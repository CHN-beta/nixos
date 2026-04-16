{ pkgs, config, lib, ... }:
{
  config =
  {
    boot =
    {
      # allow non-root users to access intel gpu performance counters
      kernel.sysctl."dev.i915.perf_stream_paranoid" = false;
      initrd.systemd =
      {
        contents."/etc/pkcs11/modules/opensc.module".source =
          config.environment.etc."pkcs11/modules/opensc.module".source;
        storePaths = [ pkgs.opensc ];
        tmpfiles.settings."10-pcscd"."/run/pcscd".d.mode = "0755";
      };
    };
    security =
    {
      pam =
      {
        u2f =
        {
          enable = true;
          settings =
          {
            cue = true;
            appid = "pam://chn.moe";
            origin = "pam://chn.moe";
            # generate using: `pamu2fcfg -u chn -o pam://chn.moe -i pam://chn.moe`
            authfile = builtins.toString (pkgs.writeText "yubikey_mappings" (builtins.concatStringsSep "\n"
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
              ])
            ]));
          };
        };
        rssh.enable = true;
        services = let u2fOrder = s: config.security.pam.services.${s}.rules.auth.u2f.order; in
        {
          sudo = { rssh = true; rules.auth.rssh.order = (u2fOrder "sudo") + 10; };
          su = { rssh = true; rules.auth.rssh.order = (u2fOrder "su") + 10; };
        };
        loginLimits =
        [
          { domain = "@users"; item = "nofile"; value = 524288; }
          # do not set stack to unlimited as default, some applications (e.g. wine) will fail
          # { domain = "@users"; item = "stack"; value = "unlimited"; }
        ];
      };
      sudo.extraConfig = "Defaults pwfeedback";
    };
    systemd =
    {
      user.extraConfig = "DefaultLimitNOFILE=524288:524288";
      tmpfiles.settings."10-pcscd"."/run/pcscd".d.mode = "0755";
    };
    # needed by xray tproxy if we want to forward traffic from other machine
    networking.firewall.checkReversePath = false;
    # this file is needed by p11tool and systemd-cryptenroll to detect opensc lib
    environment.etc."pkcs11/modules/opensc.module".text =
    ''
      module: ${pkgs.opensc}/lib/opensc-pkcs11.so
      managed: yes
    '';
    # only enable on desktop, use socket forwarding on server
    services.pcscd.enable = lib.mkIf (config.nixos.model.type == "desktop") true;
  };
}
