{ writeShellScript, writeTextDir, symlinkJoin, octodns, tokenPath, lib }:
let
  addTtl = config:
    let addTtl' = attrs: attrs // { octodns.cloudflare.auto-ttl = true; };
    in builtins.mapAttrs (n: v: if builtins.isList v then builtins.map addTtl' v else addTtl' v) config;
  config = builtins.listToAttrs (builtins.map
    (domain: { name = domain; value = import ./config/${domain}.nix { inherit lib; }; })
    [ "chn.moe" "nekomia.moe" "mirism.one" ]);
  configDir = symlinkJoin
  {
    name = "config";
    paths = builtins.map
      (domain: writeTextDir "${domain.name}.yaml" (builtins.toJSON (addTtl domain.value)))
      (lib.attrsToList config);
  };
  meta.config = config //
  {
    tinc = import ./config/tinc.nix;
    "chn.moe" = config."chn.moe"
      // {
        # 查询域名对应的 ip
        getAddress = deviceName:
          let
            dns = meta.config."chn.moe";
            f = domain:
              if dns.${domain}.type == "A" then dns.${domain}.value
              else if dns.${domain}.type == "CNAME" then f (lib.removeSuffix ".chn.moe." dns.${domain}.value)
              else throw "Not found ${domain}";
          in f deviceName;
      };
  };
in lib.addMetaAttrs meta (writeShellScript "dns-push"
''
  export OCTODNS_CONFIG=${configDir}
  export CLOUDFLARE_TOKEN=$(cat ${tokenPath})
  ${octodns}/bin/octodns-sync --config-file ${./config.yaml} --doit --force
'')
