{ lib, config, ... }:
let
  devices =
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
    programs.ssh.knownHosts = builtins.listToAttrs (builtins.concatLists (builtins.map
      (device: builtins.concatLists
      [
        [(lib.nameValuePair device.name
        {
          publicKeyFile = ././${device.name}/ssh_host_ed25519_key.pub;
          hostNames = [ "${device.name}.chn.moe" "tinc0.${device.name}.chn.moe" "${device.name}.ts.chn.moe" ]
            ++ (builtins.map (domain: "${domain}.chn.moe") device.value.extraAccess or []);
        })]
        (lib.optionals (builtins.pathExists ././${device.name}/initrd_ssh_host_ed25519_key.pub)
          [(lib.nameValuePair "initrd.${device.name}"
          {
            publicKeyFile = ././${device.name}/initrd_ssh_host_ed25519_key.pub;
            hostNames = [ "initrd.${device.name}.chn.moe" ];
          })])
      ])
      (lib.attrsToList devices)));
    nixos.user.sharedModules = [{ config.programs.ssh.matchBlocks =
      let genericConfig =
        { forwardX11 = true; forwardX11Trusted = true; forwardAgent = true; extraOptions.AddKeysToAgent = "yes"; };
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
      ]));
    }];
    environment.etc = lib.genAttrs' [ "ed25519" "rsa" ] (f: lib.nameValuePair "ssh/ssh_host_${f}_key.pub"
      { source = ././${config.nixos.model.hostname}/ssh_host_${f}_key.pub; });
  };
}
