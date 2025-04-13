localLib:
let
  cname =
  {
    autoroute = [ "api" "git" "grafana" "matrix" "peertube" "send" "synapse" "vikunja" "铜锣湾" "铜锣湾实验室" ];
    "internal.pc" = [ "internal.nix-store" ];
    nas = [ "initrd.nas" ];
    office = [ "srv2" ];
    vps6 =
    [
      "blog" "catalog" "coturn" "element" "frp" "initrd.vps6" "misskey" "nix-store" "sticker" "synapse-admin" "tgapi"
      "ua" "vps6.xserver"
    ];
    vps7 =
    [
      "chat" "freshrss" "huginn" "initrd.vps7" "nextcloud" "photoprism" "rsshub" "ssh.git" "vaultwarden" "webdav"
      "xsession.vps7"
    ];
    "xlog.autoroute" = [ "xlog" ];
  };
  a =
  {
    nas = "192.168.1.2";
    "internal.pc" = "192.168.1.3";
    office = "210.34.16.60";
    srv1 = "59.77.36.250";
    vps6 = "144.34.225.59";
    vps7 = "144.126.144.62";
    search = "127.0.0.1";
  };
  wireguard =
  {
    wg0 =
    {
      net = 83;
      peers =
      {
        vps6 = 1;
        vps7 = 2;
        pc = 3;
        nas = 4;
        one = 5;
        srv2 = 7;
        srv1 = 9;
      };
    };
  };
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
  autoroute =
  {
    type = "NS";
    values = builtins.map (suffix: "ns1.huaweicloud-dns.${suffix}.") [ "cn" "com" "net" "org" ];
  };
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
// builtins.listToAttrs (builtins.concatLists (builtins.map
  (net: builtins.map
    (peer:
    {
      name = "${net.name}.${peer.name}";
      value = { type = "A"; value = "192.168.${builtins.toString net.value.net}.${builtins.toString peer.value}"; };
    })
    (localLib.attrsToList net.value.peers))
  (localLib.attrsToList wireguard)))
