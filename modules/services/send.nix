inputs:
{
  options.nixos.services.send = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "send.chn.moe"; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) send;
    in mkIf send.enable
    {
      virtualisation.oci-containers.containers.send =
      {
        image = "timvisee/send:1ee4951";
        imageFile = inputs.pkgs.dockerTools.pullImage
        {
          imageName = "registry.gitlab.com/timvisee/send";
          imageDigest = "sha256:1ee495161f176946e6e4077e17be2b8f8634c2d502172cc530a8cd5affd7078f";
          sha256 = "1dimqga35c2ka4advhv3v60xcsdrhc6c4hh21x36fbyhk90n2vzs";
          finalImageName = "timvisee/send";
          finalImageTag = "1ee4951";
        };
        ports = [ "127.0.0.1:1443:1443/tcp" ];
        volumes = [ "send:/uploads" ];
        extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
        environmentFiles = [ inputs.config.sops.templates."send/env".path ];
      };
      sops =
      {
        templates."send/env".content =
        ''
          BASE_URL=https://${send.hostname}
          MAX_FILE_SIZE=17179869184
          REDIS_HOST=host.docker.internal
          REDIS_PORT=9184
          REDIS_PASSWORD=${inputs.config.sops.placeholder."redis/send"}
        '';
      };
      nixos =
      {
        services =
        {
          nginx =
          {
            enable = true;
            https."${send.hostname}".location."/".proxy = { upstream = "http://127.0.0.1:1443"; websocket = true; };
          };
          redis.instances.send = { user = "root"; port = 9184; };
        };
        # TODO: root docker use config of rootless docker?
        virtualization.docker.enable = true;
      };
    };
}
