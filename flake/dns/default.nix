{ writeShellScript, writeTextDir, symlinkJoin, octodns, tokenPath, localLib }:
let
  addTtl = config:
    let addTtl' = attrs: attrs // { octodns.cloudflare.auto-ttl = true; };
    in builtins.mapAttrs (n: v: if builtins.isList v then builtins.map addTtl' v else addTtl' v) config;
  config = symlinkJoin
  {
    name = "config";
    paths = builtins.map
      (domain: writeTextDir "${domain}.yaml" (builtins.toJSON (addTtl (import ./config/${domain}.nix localLib))))
      [ "chn.moe" "nekomia.moe" "mirism.one" ];
  };
in writeShellScript "dns-push"
''
  export OCTODNS_CONFIG=${config}
  export CLOUDFLARE_TOKEN=$(cat ${tokenPath})
  ${octodns}/bin/octodns-sync --config-file ${./config.yaml} --doit --force
''
