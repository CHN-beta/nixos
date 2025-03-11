inputs:
{
  options.nixos.services.xmuvpn = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) xmuvpn; in inputs.lib.mkIf (xmuvpn != null)
  {
    assertions =
    [{
      assertion = inputs.config.nixos.services.xray.client.enable;
      message = "Xray should be enabled.";
    }];
    virtualisation.oci-containers.containers.xmuvpn =
    {
      image = "hagb/docker-easyconnect";
      imageFile = inputs.topInputs.self.src.xmuvpn;
      ports = [ "127.0.0.1:5901:5901/tcp" "127.0.0.1:10069:1080/tcp" ];
      extraOptions = [ "--dns=223.5.5.5" "--device=/dev/net/tun" "--cap-add=NET_ADMIN" ];
      volumes = [ "xmuvpn:/root" ];
      environment.PASSWORD = "xxxx";
    };
    nixos.services.docker = {};
    systemd.services =
    {
      xmuvpn-forwarder =
      {
        description = "xmuvpn forwarder daemon";
        after = [ "network.target" "v2ray-forwarder.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
          let ipset = "${inputs.pkgs.ipset}/bin/ipset";
          in
          {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = inputs.pkgs.writeShellScript "xmuvpn-forwarder.start"
              (builtins.concatStringsSep "\n" (builtins.map
                (host: "${ipset} add xmu_net ${host}")
                [
                  # when add new ip, remember to also add it to router
                  "218.193.58.125" "210.34.0.35" "121.192.191.10" "10.24.84.31" "59.77.0.143" "59.77.36.248"
                  "172.27.124.24" "59.77.36.156" "59.77.36.223" "210.34.0.84" "218.193.50.157" "219.229.81.200"
                  "210.34.16.60" "10.26.14.70" "10.26.14.56" "210.34.16.20" "59.77.36.250"
                ]));
            ExecStop = inputs.pkgs.writeShellScript "xmuvpn-forwarder.stop" "${ipset} flush xmu_net";
          };
      };
      xmuvpn-ping =
      {
        description = "ping xmuvpn";
        after = [ "xmuvpn-forwarder.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
        {
          ExecStart = "${inputs.pkgs.tcping-go}/bin/tcping office.chn.moe 22 -c 0 -I 1m -H";
          Restart = "always";
        };
      };
    };
  };
}
