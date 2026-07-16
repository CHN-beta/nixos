{ self, ... }:
{
  virtualisation.oci-containers.containers.wechat = {
    imageFile = self.src.wechat;
    image = "nickrunning/wechat-selkies:0.0.12";
    ports = [ "127.0.0.1:23000:3000/tcp" ];
    volumes = [ "wechat_data:/config" ];
    extraOptions = [ "--shm-size=1gb" ];
    environment = {
      TZ = "Asia/Shanghai";
      AUTO_START_WECHAT = "true";
    };
  };
  nixos.services.nginx.https."wechat.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:23000";
}
