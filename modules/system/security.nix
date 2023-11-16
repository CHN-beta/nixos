inputs:
{
  config =
  {
    # allow non-root users to access intel gpu performance counters
    boot.kernel.sysctl."dev.i915.perf_stream_paranoid" = false;
    security.pam =
    {
      u2f =
      {
        enable = true;
        cue = true;
        appId = "pam://chn.moe";
        origin = "pam://chn.moe";
        # generate using: `pamu2fcfg -u chn -o pam://chn.moe -i pam://chn.moe`
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
          ])
        ]);
      };
      yubico = { enable = true; id = "91291"; };
    };
  };
}
