{ lib, ... }:
let
  devices =
  {
    vps4 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIF7Y0tjt1XLPjqJ8HEB26W9jVfJafRQ3pv5AbPaxEc/Z";
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIJkOPTFvX9f+Fn/KHOIvUgoRiJfq02T42lVGQhpMUGJq";
    };
    vps6 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIO5ZcvyRyOnUCuRtqrM/Qf+AdUe3a5bhbnfyhw2FSLDZ";
      # 通过 initrd.xxx.chn.moe 访问
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIB4DKB/zzUYco5ap6k9+UxeO04LL12eGvkmQstnYxgnS";
    };
    vps9 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIG+D3saEp9zThXY466WroVtqIbBSYK9M/QcsiuGgxsTV";
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAINBXlJjt2XoJvKQ8Mb91dSF1ibJAwOYzx+TPeTW6nIlT";
    };
    nas =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIIktNbEcDMKlibXg54u7QOLt0755qB/P4vfjwca8xY6V";
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIAoMu0HEaFQsnlJL0L6isnkNZdRq0OiDXyaX3+fl3NjT";
      extraAccess = [ "ssh.git" ];
    };
    pc.publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIMSfREi19OSwQnhdsE8wiNwGSFFJwNGN0M5gN+sdrrLJ";
    srv1-node0 =
      { publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIDm6M1D7dBVhjjZtXYuzMj2P1fXNWN3O9wmwNssxEeDs"; extraAccess = [ "srv1" ]; };
    srv1-node1 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIIFmG/ZzLDm23NeYa3SSI0a0uEyQWRFkaNRE9nB8egl7";
      # 不能直接访问，需要通过哪个机器跳转
      proxyJump = "srv1";
    };
    srv1-node2 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIDhgEApzHhVPDvdVFPRuJ/zCDiR1K+rD4sZzH77imKPE";
      proxyJump = "srv1";
    };
    srv2-node0 =
      { publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAINTvfywkKRwMrVp73HfHTfjhac2Tn9qX/lRjLr09ycHp"; extraAccess = [ "srv2" ]; };
    srv2-node1 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIJZ/+divGnDr0x+UlknA84Tfu6TPD+zBGmxWZY4Z38P6";
      proxyJump = "srv2";
    };
    srv2-node2 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIK9FZUOZ51pWdm2grTXDdSGMZ3g9DkvHUBvY8bFoTZjy";
      proxyJump = "srv2";
    };
  };
in
{
  config =
  {
    programs.ssh.knownHosts = builtins.listToAttrs (builtins.concatLists (builtins.map
      (device:
      [{
        inherit (device) name;
        value =
        {
          publicKey = "ssh-ed25519 ${device.value.publicKey}";
          hostNames = [ "${device.name}.chn.moe" "tinc0.${device.name}.chn.moe" "${device.name}.ts.chn.moe" ]
            ++ (builtins.map (domain: "${domain}.chn.moe") device.value.extraAccess or []);
        };
      }]
        ++ lib.optionals (device.value ? initrdPublicKey)
        [{
          name = "initrd.${device.name}";
          value =
          {
            publicKey = "ssh-ed25519 ${device.value.initrdPublicKey}";
            hostNames = [ "initrd.${device.name}.chn.moe" ];
          };
        }])
      (lib.attrsToList devices)));
    nixos.user.sharedModules = [{ config.programs.ssh.matchBlocks =
      let genericConfig =
        { forwardX11 = true; forwardX11Trusted = true; forwardAgent = true; extraOptions.AddKeysToAgent = "yes"; };
      in builtins.listToAttrs (builtins.concatLists (builtins.concatLists
      [
        # 直接访问
        (builtins.map
          (device: builtins.map
            (name:
            {
              inherit name;
              value = genericConfig //
                { host = name; hostname = "${name}.chn.moe"; proxyJump = device.value.proxyJump or null; };
            })
            ((device.value.extraAccess or []) ++ [ device.name ]))
          (lib.attrsToList devices))
        # 通过 tinc 访问
        (builtins.map
          (device: builtins.map
            (name:
            {
              name = "tinc0.${name}";
              value = genericConfig // { host = "tinc0.${name}"; hostname = "tinc0.${name}.chn.moe"; };
            })
            (device.value.extraAccess or [] ++ [ device.name ]))
          (lib.attrsToList devices))
        # 通过 tailscale 访问
        (builtins.map
          (device: builtins.map
            (name:
            {
              name = "ts.${name}";
              value = genericConfig // { host = "ts.${name}"; hostname = "${name}.ts.chn.moe"; };
            })
            (device.value.extraAccess or [] ++ [ device.name ]))
          (lib.attrsToList devices))
      ]));
    }];
  };
}
