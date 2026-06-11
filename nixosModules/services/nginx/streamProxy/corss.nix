{ lib, config, ... }:
{
  config.nixos.services.nginx.streamProxy.map = lib.mkMerge [
    # vps10 -> nas
    (lib.mkIf (config.nixos.model.hostname == "vps10") (
      [
        "peertube"
        "send"
        "freshrss"
        "nextcloud"
        "webdav"
        "synapse"
        "misskey"
        "api"
        "question"
        "xn--s8w913fdga"
        "matrix"
        "git"
      ]
      |> lib.flip lib.genAttrs' (
        site: lib.nameValuePair "${site}.chn.moe" { upstream.address = "tinc0.nas.chn.moe"; }
      )
    ))
    # vps6 -> pc
    (lib.mkIf (config.nixos.model.hostname == "vps6") {
      "xn--qbtm095lrg0bfka60z.chn.moe".upstream.address = "tinc0.pc.chn.moe";
    })
  ];
}
