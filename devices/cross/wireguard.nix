inputs:
let devices =
{
  vps6 =
  {
    peers = [ "pc" "nas" "one" "vps7" "srv2-node0" "srv1-node0" "vps8" ];
    publicKey = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
    wireguardIp = "192.168.83.1";
    listenIp = "74.211.99.69";
    lighthouse = true;
  };
  vps7 =
  {
    peers = [ "vps6" ];
    publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
    wireguardIp = "192.168.83.2";
    listenIp = "144.126.144.62";
  };
  pc =
  {
    peers = [ "vps6" ];
    behindNat = true;
    publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
    wireguardIp = "192.168.83.3";
  };
  nas =
  {
    peers = [ "vps6" ];
    behindNat = true;
    publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
    wireguardIp = "192.168.83.4";
  };
  one =
  {
    peers = [ "vps6" ];
    behindNat = true;
    publicKey = "Hey9V9lleafneEJwTLPaTV11wbzCQF34Cnhr0w2ihDQ=";
    wireguardIp = "192.168.83.5";
  };
  srv2-node0 =
  {
    peers = [ "vps6" ];
    behindNat = true;
    publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
    wireguardIp = "192.168.83.7";
  };
  srv1-node0 =
  {
    peers = [ "vps6" ];
    behindNat = true;
    publicKey = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM=";
    wireguardIp = "192.168.83.9";
  };
  vps8 =
  {
    peers = [ "vps8" ];
    publicKey = "ifOlF2zBEygsqSX48ljT9CRKx/eiTFvI78HJtmLOpnU=";
    wireguardIp = "192.168.83.6";
    listenIp = "144.34.225.59";
  };
};
in
{
  config.nixos.services.wireguard = inputs.lib.mkIf (devices ? ${inputs.config.nixos.model.hostname})
  (
    let
      buildConfig = cfg:
      {
        inherit (cfg) publicKey wireguardIp;
        lighthouse = inputs.lib.mkIf (cfg ? lighthouse) cfg.lighthouse;
        behindNat = inputs.lib.mkIf (cfg ? behindNat) cfg.behindNat;
        listenIp = inputs.lib.mkIf (cfg ? listenIp) cfg.listenIp;
      };
      this = devices.${inputs.config.nixos.model.hostname};
    in (buildConfig this) // { peers = builtins.map (peer: buildConfig (devices.${peer})) this.peers; }
  );
}
