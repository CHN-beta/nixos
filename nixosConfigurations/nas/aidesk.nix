{
  config.nixos.services.authelia = {
    users = [ "straycat" ];
    clients = [
      {
        clientId = "gitea";
        clientName = "Gitea";
        redirectUris = [ "https://gitea.chn.moe/user/oauth2/authelia/callback" ];
      }
    ];
  };
}
