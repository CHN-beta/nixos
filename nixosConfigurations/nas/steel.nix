{
  self,
  ...
}:
{
  config = {
    nixos.services.nginx.https."steel.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:3000";
    virtualisation.oci-containers.containers.steel = {
      image = "ghcr.io/steel-dev/steel-browser:latest";
      imageFile = self.src.steel-browser;
      ports = [
        "127.0.0.1:3000:3000"
      ];
    };
  };
}
