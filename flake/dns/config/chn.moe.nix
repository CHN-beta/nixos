{ lib, localLib }:
let
  cname =
  {
    nas = [ "initrd.nas" ];
    office = [ "xserverxmu" "srv2-node0" ];
    vps4 = [ "initrd.vps4" "xserver2.vps4" ];
    vps6 =
    [
      "blog" "catalog" "coturn" "element" "initrd.vps6" "sticker" "synapse-admin" "tgapi" "ua" "xserver2"
      "xserver2.vps6" "s" "headscale"
      # to pc
      "铜锣湾实验室"
    ];
    "xlog.autoroute" = [ "xlog" ];
    "tinc0.srv1-node0" = [ "tinc0.srv1" ];
    "tinc0.srv2-node0" = [ "tinc0.srv2" ];
    srv1-node0 = [ "srv1" ];
    srv2-node0 = [ "srv2" ];
    "pc.ts" = [ "nix-store" "chat" ];
    "nas.ts" = [ "ssh.git" ];
    autoroute = [ "铜锣湾" "matrix" ];
    vps9 =
    [
      "initrd.vps9" "xserver2.vps9"
      # to nas
      "git" "grafana" "peertube" "send" "vikunja" "xservernas" "freshrss" "nextcloud"
      "rsshub" "vaultwarden" "webdav" "synapse" "misskey" "api"
    ];
    "tinc0.pc" = [ "misskey-forwarder" ];
  };
  a =
  {
    nas = "192.168.1.2";
    pc = "192.168.1.3";
    office = "210.34.16.21";
    srv1-node0 = "59.77.36.250";
    vps4 = "104.234.37.61";
    vps6 = "144.34.225.59";
    vps9 = "154.3.39.17";
    search = "127.0.0.1";
    srv1-node1 = "192.168.178.2";
    srv1-node2 = "192.168.178.3";
    srv2-node1 = "192.168.178.2";
    srv2-node2 = "192.168.178.3";
    "409test" = "192.168.1.5";
  };
  tinc = import ./tinc.nix;
in
{
  "" =
  [
    { type = "ALIAS"; value = "vps6.chn.moe."; }
    {
      type = "MX";
      values =
      [
        { exchange = "tuesday.mxrouting.net."; preference = 10; }
        { exchange = "tuesday-relay.mxrouting.net."; preference = 20; }
      ];
    }
    { type = "TXT"; value = "v=spf1 include:mxlogin.com -all"; }
  ];
  "_xlog-challenge.xlog" = { type = "TXT"; value = "chn"; };
  autoroute = { type = "NS"; values = "vps6.chn.moe."; };
  ts = { type = "NS"; values = "vps6.chn.moe."; };
  "mail" = { type = "CNAME"; value = "tuesday.mxrouting.net."; };
  "webmail" = { type = "CNAME"; value = "tuesday.mxrouting.net."; };
  "x._domainkey" =
  {
    type = "TXT";
    value = ''v=DKIM1\; k=rsa\; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0CjW96ffx1tVrJkt630lSRrdEF495OAkFbUxwgZm+EjMhdQtG3erl+AzcyjK3gJpg2ylqOYxCFElerqiN9IiggYy4z6tJwVqoh7bucMbO5J4EJQvFdbyRveq7LVm+n5Qgr/CRi6105zfpzX0NbQZoLINSJMCGOmWcYPZZYv7T260ghVFkn4qVpAkFqvvc+RBtY9P96nPZ+omYvpKDV+JReNanxBZRoxuKQDpYPZhV7E6mLulzHzFyuwDLg7THBCcmEr3DlAAeZcLdm6cTdwYTG2cMv2CUiocSdxmrZeBaWa1Xef+70ddrr823o105l6PP437L4337JIMH19g9iTT+QIDAQAB'';
  };
}
// builtins.listToAttrs (builtins.concatLists (builtins.map
  (cname: builtins.map
    (name: { inherit name; value = { type = "CNAME"; value = "${cname.name}.chn.moe."; }; })
    cname.value)
  (localLib.attrsToList cname)))
// builtins.listToAttrs (builtins.map
  (a: {inherit (a) name; value = { inherit (a) value; type = "A"; }; })
  (localLib.attrsToList a))
// lib.mapAttrs'
  (n: v: lib.nameValuePair "tinc0.${n}" { type = "A"; value = "192.168.85.${builtins.toString v}"; })
  tinc
