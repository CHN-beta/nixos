{
  config,
  lib,
  pkgs,
  ...
}:
let
  users = [
    "straycat"
    "wyh"
    "lcl"
  ];
  # The SPA is served unauthenticated by the public proxy (vps6) on
  # aidesk.chn.moe; only the per-user API runs here, behind Authelia.
  domain = "api.aidesk.chn.moe";
  frontendOrigin = "https://aidesk.chn.moe";
  site = "https:${domain}";

  # nginx talks to Authelia and to the per-user backends over unix sockets
  autheliaSocket = "/run/authelia-main/authelia.sock";
  backendSocketDir = "/run/aidesk";
  backendSocket = user: "${backendSocketDir}-${user}/aidesk.sock";

  mkService = user: {
    description = "AIDesk backend for ${user}";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/${user}";
      PATH = "/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin";
      AIDESK_OMP_BIN = "/etc/profiles/per-user/${user}/bin/omp";
      PI_CODING_AGENT_DIR = "/home/${user}/.omp/agent";
    };
    serviceConfig = {
      Type = "simple";
      User = user;
      # the backend chmods its socket to 0660, so both the socket and the
      # RuntimeDirectory (0750) belong to the nginx group and only nginx can
      # connect; the service keeps the user's own uid for everything else
      Group = config.services.nginx.group;
      WorkingDirectory = "/home/${user}";
      ExecStart = "${pkgs.localPkgs.aidesk.backend}/bin/aidesk-backend --socket ${backendSocket user}";
      RuntimeDirectory = "aidesk-${user}";
      RuntimeDirectoryMode = "0750";
      Restart = "on-failure";
      RestartSec = 5;
    };
    enableDefaultPath = false;
  };
in
{
  nixos.services.authelia = {
    inherit users;
    clients = [
      {
        clientId = "gitea";
        clientName = "Gitea";
        redirectUris = [ "https://gitea.chn.moe/user/oauth2/authelia/callback" ];
      }
    ];
  };

  # the default policy is deny, so api.aidesk.chn.moe needs an explicit rule;
  # only the users that own a backend may pass
  services.authelia.instances.main.settings.access_control.rules = [
    {
      inherit domain;
      policy = "one_factor";
      subject = builtins.map (user: "user:${user}") users;
    }
  ];

  systemd.services = lib.genAttrs' users (user: lib.nameValuePair "aidesk-${user}" (mkService user));

  nixos.services.nginx.https.${domain} = {
    global.extraConfig = ''
      # terminal streams and server-sent events must not be buffered
      proxy_buffering off;
      proxy_cache off;
      gzip off;

      # The SPA runs on another origin and calls this API with the Authelia
      # cookie. "always" also covers 401/403/5xx: without it the browser turns
      # those into opaque CORS failures and fetch() cannot see the 401.
      add_header Access-Control-Allow-Origin "${frontendOrigin}" always;
      add_header Access-Control-Allow-Credentials "true" always;
      add_header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS" always;
      add_header Access-Control-Allow-Headers "Content-Type, Authorization, Accept, Cache-Control, Last-Event-ID" always;

      # A CORS preflight carries no cookie, but it must still succeed. "if" in
      # server context runs in the rewrite phase, before auth_request in the
      # access phase, so the browser gets 204 here and only the real request
      # that follows is answered with 401.
      if ($request_method = OPTIONS) {
        return 204;
      }

      # Authelia guards the whole site and tells us which user is logged in
      auth_request /internal/authelia/authz;
      auth_request_set $authelia_user $upstream_http_remote_user;
      auth_request_set $authelia_groups $upstream_http_remote_groups;
      auth_request_set $authelia_name $upstream_http_remote_name;
      auth_request_set $authelia_email $upstream_http_remote_email;
      # no error_page 401 =302: fetch() must observe the real 401 and send the
      # top-level window to Authelia itself, with "rd" pointing back here
    '';
    location = {
      # proxy_pass runs with variables, so the original request URI is forwarded
      "/api/".proxy.upstream = "http://unix:${backendSocketDir}-$authelia_user/aidesk.sock:";
    };
  };

  services.nginx.virtualHosts.${site}.locations = {
    "/api/".extraConfig = ''
      proxy_set_header Remote-User $authelia_user;
      proxy_set_header Remote-Groups $authelia_groups;
      proxy_set_header Remote-Name $authelia_name;
      proxy_set_header Remote-Email $authelia_email;
    '';
    # server level auth_request is inherited by every location, including this
    # one; without "auth_request off" the subrequest would authenticate itself
    "= /internal/authelia/authz".extraConfig = ''
      internal;
      auth_request off;
      proxy_pass http://unix:${autheliaSocket}:/api/authz/auth-request;
      proxy_set_header X-Original-Method $request_method;
      proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
      proxy_set_header X-Forwarded-For $remote_addr;
      proxy_set_header Content-Length "";
      proxy_set_header Connection "";
      proxy_pass_request_body off;
    '';
  };
}
