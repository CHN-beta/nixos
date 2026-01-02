inputs:
{
  config =
  {
    programs.ssh =
    {
      # maybe better network performance
      package = inputs.pkgs.openssh_hpn;
      startAgent = true;
      enableAskPassword = true;
      askPassword = "${inputs.pkgs.systemd}/bin/systemd-ask-password";
      extraConfig = "AddKeysToAgent yes";
      knownHosts =
        let servers =
        {
          hpc =
          {
            ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIDVpsQW3kZt5alHC6mZhay3ZEe2fRGziG4YJWCv2nn/O";
            hostnames = [ "hpc.xmu.edu.cn" ];
          };
          hpc2 =
          {
            ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIMv22sVyZ0RgFrdrHKbqOvdhq7TKZKImKwbbTbtO5jqy";
            hostnames = [ "hpc.xmu.edu.cn" ];
          };
          github =
          {
            ed25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
            hostnames = [ "github.com" ];
          };
        };
        in builtins.mapAttrs (_: v: { publicKey = "ssh-ed25519 ${v.ed25519}"; hostNames = v.hostnames; }) servers;
    };
    environment.sessionVariables.SSH_ASKPASS_REQUIRE = "prefer";
    nixos.user.sharedModules =
    [(hmInputs: {
      config.programs.ssh =
      {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = builtins.listToAttrs (builtins.map
          (host:
          {
            name = host;
            value =
            {
              host = host;
              hostname = "hpc.xmu.edu.cn";
              user = host;
            };
          })
          [ "wlin" "hwang" ])
        // rec {
          gitea = { host = "gitea"; hostname = "ssh.git.chn.moe"; };
          jykang =
          {
            host = "jykang";
            hostname = "hpc.xmu.edu.cn";
            user = "jykang";
            forwardAgent = true;
            extraOptions.AddKeysToAgent = "yes";
          };
          "tinc0.jykang" = jykang // { host = "tinc0.jykang"; proxyJump = "tinc0.nas"; };
          "*" =
          {
            controlMaster = "auto";
            controlPersist = "1m";
            compression = true;
            controlPath = "~/.ssh/master-%r@%n:%p";
          };
        };
      };
    })];
  };
}
