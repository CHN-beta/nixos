inputs:
{
  options.nixos.services.xmuvpn = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) xmuvpn; in inputs.lib.mkIf (xmuvpn != null)
  {
    virtualisation.oci-containers.containers.xmuvpn =
    {
      image = "hagb/docker-easyconnect";
      imageFile = inputs.topInputs.self.src.xmuvpn;
      ports = [ "127.0.0.1:5901:5901/tcp" "127.0.0.1:10069:1080/tcp" "--cap-add=NET_ADMIN" "-ti" ];
      extraOptions = [ "--dns=223.5.5.5" "--device=/dev/net/tun" ];
      volumes = [ "xmuvpn:/root" ];
      environment.PASSWORD = "xxxx";
    };
    nixos.services.docker = {};
  };
}
