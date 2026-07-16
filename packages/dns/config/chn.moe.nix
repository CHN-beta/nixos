{ lib }:
let
  cname = {
    nas = [ "initrd.nas" ];
    office = [ "srv2-node0" ];
    vps4 = [
      "initrd.vps4"
      "xserver2.vps4"
      "status"
    ];
    vps6 = [
      "blog"
      "catalog"
      "coturn"
      "element"
      "initrd.vps6"
      "sticker"
      "synapse-admin"
      "tgapi"
      "ua"
      "xserver2"
      "xserver2.vps6"
      "s"
      "headscale"
      "missgram"
      "xserver3"
      # to pc
      "铜锣湾实验室"
      # temporary
      "hongbao2026"
    ];
    # temporary
    "remove-me.vps6" = [ "zzzhongbao2026" ];
    "tinc0.srv1-node0" = [ "tinc0.srv1" ];
    "tinc0.srv2-node0" = [ "tinc0.srv2" ];
    srv1-node0 = [ "srv1" ];
    srv2-node0 = [
      "srv2"
      "jupyterhub"
    ];
    "pc.ts" = [
      "nix-store"
    ];
    "nas.ts" = [
      "ssh.git"
      "backup-store"
      "rsshub"
      "grafana"
      "huginn"
      "vaultwarden"
      "photo"
      "readeck"
      "nextcloud"
      "ha"
      "frigate"
      "wechat"
    ];
    vps10 = [
      "initrd.vps10"
      "xserver2.vps10"
      # to nas
      "peertube"
      "send"
      "freshrss"
      "webdav"
      "synapse"
      "misskey"
      "api"
      "question"
      "铜锣湾"
      "matrix"
      "git"
    ];
  };
  a_aaaa = {
    office = "210.34.16.100";
    srv1-node0 = "59.77.36.250";
    vps4 = "59.152.127.72";
    vps6 = {
      A = "144.34.225.59";
      AAAA = "2607:8700:5500:2255::2";
    };
    vps10 = "157.254.234.38";
    search = "127.0.0.1";
    # temporary
    "remove-me.vps6" = [ "127.0.0.1" ];
  };
  tinc = import ./tinc.nix;
in
{
  "" = [
    {
      type = "ALIAS";
      value = "vps6.chn.moe.";
    }
    {
      type = "MX";
      values = [
        {
          exchange = "tuesday.mxrouting.net.";
          preference = 10;
        }
        {
          exchange = "tuesday-relay.mxrouting.net.";
          preference = 20;
        }
      ];
    }
    {
      type = "TXT";
      value = "v=spf1 include:mxlogin.com -all";
    }
  ];
  ts = {
    type = "NS";
    values = "vps6.chn.moe.";
  };
  "mail" = {
    type = "CNAME";
    value = "tuesday.mxrouting.net.";
  };
  "webmail" = {
    type = "CNAME";
    value = "tuesday.mxrouting.net.";
  };
  "x._domainkey" = {
    type = "TXT";
    value = ''v=DKIM1\; k=rsa\; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0CjW96ffx1tVrJkt630lSRrdEF495OAkFbUxwgZm+EjMhdQtG3erl+AzcyjK3gJpg2ylqOYxCFElerqiN9IiggYy4z6tJwVqoh7bucMbO5J4EJQvFdbyRveq7LVm+n5Qgr/CRi6105zfpzX0NbQZoLINSJMCGOmWcYPZZYv7T260ghVFkn4qVpAkFqvvc+RBtY9P96nPZ+omYvpKDV+JReNanxBZRoxuKQDpYPZhV7E6mLulzHzFyuwDLg7THBCcmEr3DlAAeZcLdm6cTdwYTG2cMv2CUiocSdxmrZeBaWa1Xef+70ddrr823o105l6PP437L4337JIMH19g9iTT+QIDAQAB'';
  };
}
// builtins.listToAttrs (
  builtins.concatLists (
    builtins.map (
      cname:
      builtins.map (name: {
        inherit name;
        value = {
          type = "CNAME";
          value = "${cname.name}.chn.moe.";
        };
      }) cname.value
    ) (lib.attrsToList cname)
  )
)
// lib.mapAttrs (
  n: v:
  if (lib.isAttrs v) then
    lib.mapAttrsToList (n: v: {
      value = v;
      type = n;
    }) v
  else
    {
      value = v;
      type = "A";
    }
) a_aaaa
// lib.mapAttrs' (
  n: v:
  lib.nameValuePair "tinc0.${n}" {
    type = "A";
    value = "192.168.85.${builtins.toString v}";
  }
) tinc
