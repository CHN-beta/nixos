inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nix = { marches = [ "cascadelake" "broadwell" ]; remote.slave.enable = true; };
        nixpkgs.march = "cascadelake";
        networking.networkd.static =
        {
          eno145 = { ip = "192.168.1.10"; mask = 24; gateway = "192.168.1.1"; };
          eno146 = { ip = "192.168.178.1"; mask = 24; };
        };
        cluster.nodeType = "master";
      };
      services =
      {
        xray.client =
        {
          enable = true;
          dnsmasq.extraInterfaces = [ "eno146" ];
        };
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM=";
          wireguardIp = "192.168.83.9";
        };
      };
    };
    services.nfs.server =
    {
      enable = true;
      exports = 
      ''
        / 192.168.178.0/24(rw,no_root_squash,fsid=0,sync,crossmnt)
        /home 192.168.178.0/24(rw,no_root_squash,sync,crossmnt)
      '';
    };
    networking =
    {
      firewall.allowedTCPPorts = [ 2049 ];
    };
    systemd.network.networks."10-eno146".networkConfig.IPMasquerade = "both";
    services.rpcbind.enable = true;
    fileSystems =
    {
      "/nix/share/home" =
      {
        device = "/home";
        options = [ "rbind" ];
      };
    };
    # without this, tproxy does not work
    # TODO: why?
    networking.firewall.trustedInterfaces = [ "eno146" ];
  };
}
