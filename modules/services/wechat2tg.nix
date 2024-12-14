inputs:
{
  options.nixos.services.wechat2tg = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) wechat2tg; in inputs.lib.mkIf (wechat2tg != null)
  {
    virtualisation.oci-containers.containers.wechat2tg =
    {
      image = "finalpi/wechat2tg:v1.3.3";
      imageFile = inputs.pkgs.dockerTools.pullImage
      {
        imageName = "finalpi/wechat2tg";
        imageDigest = "sha256:48e3aff3f501847f063318b41ca34af7d83278847d2eee40d7ffbf439ee4c194";
        sha256 = "04hq577d981mdfz0xwklhj9ifgnpbv91d6zkf37awfrbsiqfkrr6";
        finalImageName = "finalpi/wechat2tg";
        finalImageTag = "v1.3.3";
      };
      volumes = [ "wechat2tg-config:/app/storage" "wechat2tg-files:/app/save-files" ];
      environmentFiles = [ inputs.config.sops.templates."wechat2tg/env".path ];
    };
    sops =
    {
      templates."wechat2tg/env".content = let placeholder = inputs.config.sops.placeholder; in
      ''
        BOT_TOKEN=${placeholder."wechat2tg/token"}
        # PROXY_HOST: ""
        # PROXY_PORT: ""
        # Proxy type: socks5, http, https
        # PROXY_PROTOCOL: 'socks5'
        # Optional username and password
        # PROXY_USERNAME: ""
        # PROXY_PASSWORD: ""
        # API_ID: ""
        # API_HASH: ""
        ROOM_MESSAGE='<i>🌐#[topic]</i> ---- <b>👤#[(alias)] #[name]: </b>'
        OFFICIAL_MESSAGE='<b>📣#[name]: </b>'
        CONTACT_MESSAGE='<b>👤#[alias_first]: </b>'
        ROOM_MESSAGE_GROUP='<b>👤#[(alias)] #[name]: </b>'
        OFFICIAL_MESSAGE_GROUP='<b>📣#[name]: </b>'
        CONTACT_MESSAGE_GROUP='<b>👤#[alias_first]: </b>'
        CREATE_ROOM_NAME='#[topic]'
        CREATE_CONTACT_NAME='#[alias]#[[name]]'
        MESSAGE_DISPLAY='#[identity]#[br]#[body]'
      '';
      secrets."wechat2tg/token" = {};
    };
  };
}
