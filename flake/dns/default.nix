{ writeShellScript, writeTextDir, symlinkJoin, octodns, tokenPath, localLib, lib }:
let
  addTtl = config:
    let addTtl' = attrs: attrs // { octodns.cloudflare.auto-ttl = true; };
    in builtins.mapAttrs (n: v: if builtins.isList v then builtins.map addTtl' v else addTtl' v) config;
  config = builtins.listToAttrs (builtins.map
    (domain: { name = domain; value = import ./config/${domain}.nix localLib; })
    [ "chn.moe" "nekomia.moe" "mirism.one" ]);
  configDir = symlinkJoin
  {
    name = "config";
    paths = builtins.map
      (domain: writeTextDir "${domain.name}.yaml" (builtins.toJSON (addTtl domain.value)))
      (localLib.attrsToList config);
  };
in lib.addMetaAttrs { config = config // { wireguard = import ./config/wireguard.nix; }; } (writeShellScript "dns-push"
''
  export OCTODNS_CONFIG=${config}
  export CLOUDFLARE_TOKEN=$(cat ${tokenPath})
  ${octodns}/bin/octodns-sync --config-file ${./config.yaml} --doit --force
'')
