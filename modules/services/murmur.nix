inputs:
{
  options.nixos.services.murmur = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule
    {
      options =
      {
        hostname = mkOption { type = types.nonEmptyStr; default = "murmur.chn.moe"; };
      };
    });
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) murmur; in inputs.lib.mkIf (murmur != null)
  {
    services.murmur =
    {
      enable = true;
      openFirewall = true;
      password = "$MURMURD_PASSWORD";
      sslKey = "${inputs.config.security.acme.certs.${murmur.hostname}.directory}/key.pem";
      sslCert = "${inputs.config.security.acme.certs.${murmur.hostname}.directory}/fullchain.pem";
      environmentFile = inputs.config.sops.templates."murmur/env".path;
    };
    sops =
    {
      templates."murmur/env" =
      {
        content = "MURMURD_PASSWORD=${inputs.config.sops.placeholder."murmur/password"}";
        owner = "murmur";
      };
      secrets."murmur/password" = {};
    };
    nixos.services.acme.cert.${murmur.hostname}.group = "murmur";
  };
}
