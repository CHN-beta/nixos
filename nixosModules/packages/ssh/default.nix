{ pkgs, lib, config, ... }:
let devices =
{
  vps4 = {};
  vps6 = {};
  vps9 = {};
  nas = { extraAccess = [ "ssh.git" ]; proxyJump = "srv2"; };
  pc = {};
  srv1-node0.extraAccess = [ "srv1" ];
  srv1-node1.proxyJump = "srv1";
  srv1-node2.proxyJump = "srv1";
  srv2-node0.extraAccess = [ "srv2" ];
  srv2-node1.proxyJump = "srv2";
  srv2-node2.proxyJump = "srv2";
  pe = {};
};
in
{
  config =
  {
    programs.ssh =
    {
      # maybe better network performance
      package = pkgs.openssh_hpn;
      startAgent = true;
      enableAskPassword = true;
      askPassword = "${pkgs.systemd}/bin/systemd-ask-password";
      extraConfig = "AddKeysToAgent yes";
      knownHosts = lib.mkMerge
      [
        (builtins.listToAttrs (builtins.concatLists (builtins.map
          (device: builtins.concatLists
          [
            [(lib.nameValuePair device.name
            {
              publicKeyFile = ./devices/${device.name}/ssh_host_ed25519_key.pub;
              hostNames = [ "${device.name}.chn.moe" "tinc0.${device.name}.chn.moe" "${device.name}.ts.chn.moe" ]
                ++ (builtins.map (domain: "${domain}.chn.moe") device.value.extraAccess or []);
            })]
            (lib.optionals (builtins.pathExists ./devices/${device.name}/initrd_ssh_host_ed25519_key.pub)
              [(lib.nameValuePair "initrd.${device.name}"
              {
                publicKeyFile = ./devices/${device.name}/initrd_ssh_host_ed25519_key.pub;
                hostNames = [ "initrd.${device.name}.chn.moe" ];
              })])
          ])
          (lib.attrsToList devices))))
        (
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
          in builtins.mapAttrs (_: v: { publicKey = "ssh-ed25519 ${v.ed25519}"; hostNames = v.hostnames; }) servers
        )
      ];
    };
    environment =
    {
      sessionVariables.SSH_ASKPASS_REQUIRE = "prefer";
      etc = lib.genAttrs' [ "ed25519" "rsa" ] (f: lib.nameValuePair "ssh/ssh_host_${f}_key.pub"
        { source = ./devices/${config.nixos.model.hostname}/ssh_host_${f}_key.pub; });
    };
    nixos.user.sharedModules =
    [(hmInputs: {
      config.programs.ssh =
      {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = lib.mkMerge
        [
          (lib.genAttrs [ "wlin" "hwang" ] (n: { host = n; hostname = "hpc.xmu.edu.cn"; user = n; }))
          rec {
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
          }
          (
            let genericConfig =
            {
              forwardX11 = true;
              forwardX11Trusted = true;
              forwardAgent = true;
              extraOptions.AddKeysToAgent = "yes";
            };
            in builtins.listToAttrs (builtins.concatLists (builtins.concatLists
            [
              # 直接访问
              (builtins.map
                (device: builtins.map
                  (name: lib.nameValuePair name (genericConfig //
                    { host = name; hostname = "${name}.chn.moe"; proxyJump = device.value.proxyJump or null; }))
                  ((device.value.extraAccess or []) ++ [ device.name ]))
                (lib.attrsToList devices))
              # 通过 tinc 访问
              (builtins.map
                (device: builtins.map
                  (name: lib.nameValuePair "tinc0.${name}" (genericConfig //
                    { host = "tinc0.${name}"; hostname = "tinc0.${name}.chn.moe"; }))
                  (device.value.extraAccess or [] ++ [ device.name ]))
                (lib.attrsToList devices))
              # 通过 tailscale 访问
              (builtins.map
                (device: builtins.map
                  (name: lib.nameValuePair "ts.${name}" (genericConfig //
                    { host = "ts.${name}"; hostname = "${name}.ts.chn.moe"; }))
                  (device.value.extraAccess or [] ++ [ device.name ]))
                (lib.attrsToList devices))
            ]))
          )
        ];
      };
    })];
  };
}
