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
        controlMaster = "auto";
        controlPersist = "1m";
        compression = true;
        matchBlocks = builtins.listToAttrs
        (
          # TODO: 分离到 cross
          (builtins.map
            (host: { name = host; value = { inherit host; hostname = "${host}.chn.moe"; }; })
            [ "vps6" "wg0.vps6" "vps7" "wg0.vps7" "wg0.nas" "wg0.one" ])
          ++ (builtins.map
            (host:
            {
              name = host;
              value = { inherit host; hostname = "${host}.chn.moe"; forwardX11 = true; forwardX11Trusted = true; };
            })
            [ "wg0.pc" "srv1" "wg0.srv1" "srv2" "wg0.srv2" "srv3" "wg0.srv3" ])
          ++ (builtins.map
            (host:
            {
              name = host;
              value =
              {
                host = host;
                hostname = "hpc.xmu.edu.cn";
                user = host;
                setEnv.TERM = "chn_unset_ls_colors:xterm-256color";
              };
            })
            [ "wlin" "hwang" ])
        )
        // rec {
          nas = { host = "nas"; hostname = "192.168.1.2"; forwardX11 = true; forwardX11Trusted = true; };
          pc = { host = "pc"; hostname = "192.168.1.3"; forwardX11 = true; forwardX11Trusted = true; };
          one = { host = "one"; hostname = "192.168.1.4"; forwardX11 = true; forwardX11Trusted = true; };
          gitea = { host = "gitea"; hostname = "ssh.git.chn.moe"; };
          jykang =
          {
            host = "jykang";
            hostname = "hpc.xmu.edu.cn";
            user = "jykang";
            forwardAgent = true;
            extraOptions.AddKeysToAgent = "yes";
          };
          "wg0.jykang" = jykang // { host = "wg0.jykang"; proxyJump = "wg0.srv2"; };
          srv1-node0 = { host = "srv1-node0"; hostname = "srv1.chn.moe"; };
          srv1-node1 = { host = "srv1-node1"; hostname = "192.168.178.2"; proxyJump = "srv1"; };
          srv1-node2 = { host = "srv1-node2"; hostname = "192.168.178.3"; proxyJump = "srv1"; };
          srv2-node0 = { host = "srv2-node0"; hostname = "srv2.chn.moe"; };
          srv2-node1 = { host = "srv2-node1"; hostname = "192.168.178.2"; proxyJump = "srv2"; };
        };
      };
    })];
  };
}
