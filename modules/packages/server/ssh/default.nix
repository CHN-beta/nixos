inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (builtins) concatLists map listToAttrs;
      inherit (inputs.localLib) attrsToList;
    in mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
    {
      services.openssh.knownHosts =
        let
          servers =
          {
            vps6 =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO5ZcvyRyOnUCuRtqrM/Qf+AdUe3a5bhbnfyhw2FSLDZ";
              hostnames =
              [
                "vps6.chn.moe" "internal.vps6.chn.moe" "wireguard.vps6.chn.moe"
                "74.211.99.69" "192.168.82.1" "192.168.83.1"
              ];
            };
            "initrd.vps6" =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4DKB/zzUYco5ap6k9+UxeO04LL12eGvkmQstnYxgnS";
              hostnames = [ "initrd.vps6.chn.moe" "74.211.99.69" ];
            };
            vps7 =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF5XkdilejDAlg5hZZD0oq69k8fQpe9hIJylTo/aLRgY";
              hostnames =
              [
                "vps7.chn.moe" "internal.vps7.chn.moe" "wireguard.vps7.chn.moe"
                "95.111.228.40" "192.168.82.2" "192.168.83.2"
              ];
            };
            "initrd.vps7" =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZyQpdQmEZw3nLERFmk2tS1gpSvXwW0Eish9UfhrRxC";
              hostnames = [ "initrd.vps7.chn.moe" "95.111.228.40" ];
            };
            nas =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIktNbEcDMKlibXg54u7QOLt0755qB/P4vfjwca8xY6V";
              hostnames =
              [
                "internal.nas.chn.moe" "wireguard.nas.chn.moe" "[office.chn.moe]:5440"
                "192.168.1.185" "192.168.82.4" "192.168.83.4"
              ];
            };
            "initrd.nas" =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAoMu0HEaFQsnlJL0L6isnkNZdRq0OiDXyaX3+fl3NjT";
              hostnames = [ "initrd.nas.chn.moe" "[office.chn.moe]:5440" "192.168.1.185" ];
            };
            pc =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSfREi19OSwQnhdsE8wiNwGSFFJwNGN0M5gN+sdrrLJ";
              hostnames = [ "internal.pc.chn.moe" "wireguard.pc.chn.moe" "192.168.82.3" "192.168.83.3" ];
            };
            hpc =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDVpsQW3kZt5alHC6mZhay3ZEe2fRGziG4YJWCv2nn/O";
              hostnames = [ "hpc.xmu.edu.cn" ];
            };
            github =
            {
              ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
              hostnames = [ "github.com" ];
            };
          };
        in listToAttrs (concatLists (map
          (server:
          (
            if builtins.pathExists ./ssh/${server.name}_rsa.pub then
            [{
              name = "${server.name}-rsa";
              value =
              {
                publicKey = builtins.readFile ./ssh/${server.name}_rsa.pub;
                hostNames = server.value.hostnames;
              };
            }]
            else []
          )
          ++ (
            if builtins.pathExists ./ssh/${server.name}_ecdsa.pub then
            [{
              name = "${server.name}-ecdsa";
              value =
              {
                publicKey = builtins.readFile ./ssh/${server.name}_ecdsa.pub;
                hostNames = server.value.hostnames;
              };
            }]
            else []
          )
          ++ (
            if server.value ? ed25519 then
            [{
              name = "${server.name}-ed25519";
              value =
              {
                publicKey = server.value.ed25519;
                hostNames = server.value.hostnames;
              };
            }]
            else []
          ))
          (attrsToList servers)));
      nixos.users.sharedModules =
      [{
        config.programs.ssh =
        {
          enable = true;
          controlMaster = "auto";
          controlPersist = "1m";
          compression = true;
          matchBlocks = builtins.listToAttrs
          (
            (builtins.map
              (host: { name = host; value = { inherit host; hostname = "${host}.chn.moe"; }; })
              [
                "vps6" "internal.vps6" "wireguard.vps6" "vps7" "internal.vps7" "wireguard.vps7"
                "internal.pc" "wireguard.pc" "internal.nas" "wireguard.nas"
              ])
            ++ (builtins.map
              (host:
              {
                name = host;
                value =
                {
                  host = host;
                  hostname = "hpc.xmu.edu.cn";
                  user = host;
                  extraOptions =
                  {
                    PubkeyAcceptedAlgorithms = "+ssh-rsa";
                    HostkeyAlgorithms = "+ssh-rsa";
                    SetEnv = "TERM=chn_unset_ls_colors:xterm-256color";
                    # in .bash_profile:
                    # if [[ $TERM == chn_unset_ls_colors* ]]; then
                    #   export TERM=${TERM#*:}
                    #   export CHN_LS_USE_COLOR=1
                    # fi
                    # in .bashrc
                    # [ -n "$CHN_LS_USE_COLOR" ] && alias ls="ls --color=auto"
                  };
                };
              })
              [ "wlin" "jykang" "hwang" ])
          )
          // {
            xmupc1 = { host = "xmupc1"; hostname = "office.chn.moe"; port = 6007; };
            nas = { host = "nas"; hostname = "office.chn.moe"; port = 5440; };
          };
        };
      }];
    };
}
