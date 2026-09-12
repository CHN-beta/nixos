{ self, ... }:
{
  config = {
    virtualisation.oci-containers.containers.redroid = {
      imageFile = self.src.redroid;
      image = "redroid/redroid:11.0.0-latest";
      ports = [ "0.0.0.0:5555:5555" ];
      volumes = [
        "redroid:/data"
        "/dev/dri:/dev/dri"
        "/dev/net/tun:/dev/tun"
      ];
      privileged = true;
      cmd = [
        "androidboot.redroid_width=1280"
        "androidboot.redroid_height=720"
        "androidboot.redroid_dpi=160"
        "androidboot.redroid_gpu_mode=host"
        "androidboot.redroid_gpu_node=/dev/dri/renderD128"
      ];
    };
  };
}
