inputs:
{
  options.nixos.services.chatgpt = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.str; default = "chat.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) chatgpt; in inputs.lib.mkIf (chatgpt != null)
  {
    virtualisation.oci-containers.containers.chatgpt =
    {
      image = "yidadaa/chatgpt-next-web:v2.11.3";
      imageFile = inputs.pkgs.dockerTools.pullImage
      {
        imageName = "yidadaa/chatgpt-next-web";
        imageDigest = "sha256:622462a7958f82e128a0e1ebd07b96e837f3d457b912fb246b550fb730b538a7";
        sha256 = "00qwh1kjdchf1nhaz18s2yly2xhvpaa83ym5x4wy3z0y3vc1zwxx";
        finalImageName = "yidadaa/chatgpt-next-web";
        finalImageTag = "v2.11.3";
      };
      ports = [ "127.0.0.1:6184:3000/tcp" ];
      extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
      environmentFiles = [ inputs.config.sops.templates."chatgpt/env".path ];
    };
    sops =
    {
      templates."chatgpt/env".content =
      ''
        OPENAI_API_KEY=${inputs.config.sops.placeholder."chatgpt/key"}
        BASE_URL=https://oa.api2d.net
      '';
      secrets."chatgpt/key" = {};
    };
    nixos.services.nginx =
    {
      enable = true;
      https."${chatgpt.hostname}".location."/".proxy =
        { upstream = "http://127.0.0.1:6184"; detectAuth.users = [ "chat" ]; };
    };
  };
}
