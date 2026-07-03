{
  writeShellScript,
  writeTextDir,
  symlinkJoin,
  octodns,
  tokenPath,
  lib,
}:
let
  addTtl =
    config:
    let
      addTtl' = attrs: attrs // { octodns.cloudflare.auto-ttl = true; };
    in
    builtins.mapAttrs (n: v: if builtins.isList v then builtins.map addTtl' v else addTtl' v) config;
  config = builtins.listToAttrs (
    builtins.map
      (domain: {
        name = domain;
        value = import ./config/${domain}.nix { inherit lib; };
      })
      [
        "chn.moe"
        "nekomia.moe"
        "mirism.one"
      ]
  );
  configDir = symlinkJoin {
    name = "config";
    paths = builtins.map (
      domain: writeTextDir "${domain.name}.yaml" (builtins.toJSON (addTtl domain.value))
    ) (lib.attrsToList config);
  };
  meta.config = config // {
    tinc = import ./config/tinc.nix;
    "chn.moe" = config."chn.moe" // {
      # 查询域名对应的 ip
      getAddress =
        deviceName:
        let
          dns = meta.config."chn.moe";
          getAttrFromList =
            type: domain:
            let
              result = lib.filter (attr: attr.type == type) domain;
            in
            if result == [ ] then null else (lib.head result).value;
          getAttr =
            type: domain:
            if lib.isAttrs domain then getAttrFromList type [ domain ] else getAttrFromList type domain;
          f =
            domain:
            let
              recordA = getAttr "A" dns.${domain};
              recordCNAME = getAttr "CNAME" dns.${domain};
            in
            if recordCNAME != null then
              f (lib.removeSuffix ".chn.moe." recordCNAME)
            else if recordA != null then
              recordA
            else
              throw "Not found ${domain}";
        in
        f deviceName;
    };
  };
in
lib.addMetaAttrs meta (
  writeShellScript "dns-push" ''
    export OCTODNS_CONFIG=${configDir}
    export CLOUDFLARE_TOKEN=$(cat ${tokenPath})
    ${octodns}/bin/octodns-sync --config-file ${./config.yaml} --doit --force
  ''
)
