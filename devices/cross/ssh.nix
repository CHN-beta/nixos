inputs:
let
  devices =
  {
    vps6 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIO5ZcvyRyOnUCuRtqrM/Qf+AdUe3a5bhbnfyhw2FSLDZ";
      # 通过 initrd.xxx.chn.moe 访问
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIB4DKB/zzUYco5ap6k9+UxeO04LL12eGvkmQstnYxgnS";
    };
    vps7 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIF5XkdilejDAlg5hZZD0oq69k8fQpe9hIJylTo/aLRgY";
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIGZyQpdQmEZw3nLERFmk2tS1gpSvXwW0Eish9UfhrRxC";
      # 默认仅包括wireguard访问的域名和直接访问的域名，这里写额外的域名
      extraAccess = [ "ssh.git" ];
    };
    nas =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIIktNbEcDMKlibXg54u7QOLt0755qB/P4vfjwca8xY6V";
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIAoMu0HEaFQsnlJL0L6isnkNZdRq0OiDXyaX3+fl3NjT";
    };
    one.publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIC5i2Z/vK0D5DBRg3WBzS2ejM0U+w3ZPDJRJySdPcJ5d";
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
      { publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIJZ/+divGnDr0x+UlknA84Tfu6TPD+zBGmxWZY4Z38P6"; extraAccess = [ "srv2" ]; };
    srv2-node1 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAINTvfywkKRwMrVp73HfHTfjhac2Tn9qX/lRjLr09ycHp";
      proxyJump = "srv2";
    };
    srv3 =
    {
      publicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIIg2wuwWqIOWNx1kVmreF6xTrGaW7rIaXsEPfCMe+5P9";
      initrdPublicKey = "AAAAC3NzaC1lZDI1NTE5AAAAIPW7XPhNsIV0ZllaueVMHIRND97cHb6hE9O21oLaEdCX";
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
          hostNames =
            # 直接访问
            [ "${device.name}.chn.moe" ]
            # 通过 wirewireguard 访问
            ++ (builtins.map (net: "${net}.${device.name}.chn.moe")
              (builtins.attrNames inputs.topInputs.self.config.dns.wireguard.net))
            # 额外的域名
            ++ (builtins.map (domain: "${domain}.chn.moe") device.value.extraAccess or []);
        };
      }]
        ++ inputs.lib.optionals (device.value ? initrdPublicKey)
        [{
          name = "initrd.${device.name}";
          value =
          {
            publicKey = "ssh-ed25519 ${device.value.initrdPublicKey}";
            hostNames = [ "initrd.${device.name}.chn.moe" ];
          };
        }])
      (inputs.localLib.attrsToList devices)));
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
          (inputs.localLib.attrsToList devices))
        # 通过 wireguard 访问
        (builtins.concatLists (builtins.map
          (net: builtins.map
            (device: builtins.map
              (name:
              {
                name = "${net}.${name}";
                value = genericConfig // { host = "${net}.${name}"; hostname = "${net}.${name}.chn.moe"; };
              })
              ((device.value.extraAccess or []) ++ [ device.name ]))
            (inputs.localLib.attrsToList devices))
          (builtins.attrNames inputs.topInputs.self.config.dns.wireguard.net)))
      ]));
    }];
  };
}
