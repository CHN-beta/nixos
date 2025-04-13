inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.model.hostname == "srv1-node0")
  {
    nixos =
    {
      model.cluster.nodeType = "master";
      system =
      {
        nixpkgs.march = "cascadelake";
        networking.static =
        {
          eno145 = { ip = "192.168.1.10"; mask = 24; gateway = "192.168.1.1"; };
          eno146 = { ip = "192.168.178.1"; mask = 24; };
        };
      };
      services =
      {
        xray.client = { enable = true; dnsmasq.extraInterfaces = [ "eno146" ]; };
        beesd."/" = { hashTableSizeMB = 128; threads = 4; };
        xrdp = { enable = true; hostname = [ "srv1.chn.moe" ]; };
        samba = { hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
      };
      packages.packages._prebuildPackages =
        [ inputs.topInputs.self.nixosConfigurations.srv1-node1.pkgs.localPackages.vasp.intel ];
    };
    # allow other machine access network by this machine
    systemd.network.networks."10-eno146".networkConfig.IPMasquerade = "both";
    # without this, tproxy does not work
    # TODO: why?
    networking.firewall.trustedInterfaces = [ "eno146" ];
  };
}
