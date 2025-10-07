inputs:
let
  configs =
  {
    pc =
    {
      settings =
      {
        # 如何连接到这个节点
        addresses = [{ address = "192.168.1.3"; }];
        # 通过这个节点可以访问哪些地址，用于路由
        subnets = [{ address = "192.168.85.3"; weight = 1; }];
        settings.Ed25519PublicKey = "soafMZ/0EViMhKYNc8g8pp4sbhR/2HnnXwGQln0BgCK";
      };
      # 这个接口的地址
      address = "192.168.85.3";
      useNetworkd = false;
    };
    nas =
    {
      settings =
      {
        addresses = [{ address = "192.168.1.2"; }];
        subnets = [{ address = "192.168.85.4"; weight = 1; }];
        settings.Ed25519PublicKey = "sSN3eeBgrMXF6/XYfEBe54TXmfHETOESX+SyrpGlmDK";
      };
      address = "192.168.85.4";
      useNetworkd = true;
    };
    vps6 =
    {
      settings =
      {
        addresses = [{ address = "144.34.225.59"; }];
        subnets =
        [
          { address = "192.168.85.1"; weight = 1; }
          # { address = "192.168.85.0"; prefixLength = 24; weight = 10; }
        ];
        settings.Ed25519PublicKey = "rYOCGG+B4isTifKJQqsEdfhQuQRnUiIsvz7uI7vZiDN";
      };
      address = "192.168.85.1";
      useNetworkd = true;
    };
    vps4 =
    {
      settings =
      {
        addresses = [{ address = "104.234.37.61"; }];
        subnets =
        [
          { address = "192.168.85.2"; weight = 1; }
          { address = "192.168.85.0"; prefixLength = 24; weight = 10; }
        ];
        settings.Ed25519PublicKey = "N03OoCyj4ADkeN3cimJI/bJrBw8g1kz3TJ+1BTe+oyA";
      };
      address = "192.168.85.2";
      useNetworkd = true;
    };
  };
in
{
  config = inputs.lib.mkIf (builtins.hasAttr inputs.config.nixos.model.hostname configs)
  {
    services.tinc.networks.tinc0 = 
    {
      settings =
      {
        Interface = "tinc0";
        # Name = builtins.replaceStrings [ "-" ] [ "_" ] inputs.config.nixos.model.hostname;
        Name = inputs.config.nixos.model.hostname;
      };
      hostSettings = builtins.mapAttrs (n: v: v.settings) configs;
      ed25519PrivateKeyFile = inputs.config.nixos.system.sops.secrets."tinc".path;
    };
    nixos.system =
    {
      sops.secrets."tinc".owner = "tinc-tinc0";
      network.settings = inputs.lib.mkIf (configs.${inputs.config.nixos.model.hostname}.useNetworkd)
      {
        static."tinc0" = { ip = configs.${inputs.config.nixos.model.hostname}.address; mask = 24; };
      };
    };
    # systemd.network.networks = inputs.lib.mkIf (configs.${inputs.config.nixos.model.hostname}.useNetworkd)
    # {
    #   "10-custom" =
    #   {
    #     matchConfig.Name = "tinc0";
    #     routes = [{ Destination = "192.168.85.0/0"; }];
    #   };
    # };
    environment.etc = inputs.lib.mkIf (!configs.${inputs.config.nixos.model.hostname}.useNetworkd)
    {
      "tinc/tinc0/tinc-up".source = inputs.pkgs.writeShellScript "tinc-up"
      ''
        ${inputs.pkgs.iproute2}/bin/ip link set $INTERFACE up
        ${inputs.pkgs.iproute2}/bin/ip addr add ${configs.${inputs.config.nixos.model.hostname}.address}/24 dev $INTERFACE
      '';
    };
    networking.firewall = { allowedTCPPorts = [ 655 ]; allowedUDPPorts = [ 655 ]; };
  };
}
