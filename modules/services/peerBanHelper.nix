inputs:
{
  options.nixos.services.peerBanHelper = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) peerBanHelper; in inputs.lib.mkIf (peerBanHelper != null)
  {
    virtualisation.oci-containers.containers.peerBanHelper =
    {
      inherit (inputs.topInputs.self.src.peerBanHelper) image imageFile;
      volumes = [ "peerBanHelper:/app/data" ];
      ports = [ "9898:9898/tcp" ];
      environment = { PUID = "0"; PGID = "0"; TZ = "UTC"; };
    };
    nixos.services.podman = {};
  };
}
