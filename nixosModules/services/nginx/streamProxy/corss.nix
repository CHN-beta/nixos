{ lib, config, ... }:
{
  config.nixos.services.nginx.streamProxy.map = lib.mkMerge [
    # vps6 & vps9 -> nas
    (lib.mkIf
      (lib.elem config.nixos.model.hostname [
        "vps6"
        "vps9"
      ])
      (
        [
          "xn--s8w913fdga"
          "matrix"
          "send"
          "git"
          "peertube"
          "misskey"
          "synapse"
          "nextcloud"
          "freshrss"
          "api"
          "webdav"
          "matrix"
          "git"
          "question"
        ]
        |> lib.flip lib.genAttrs' (
          site: lib.nameValuePair "${site}.chn.moe" { upstream.address = "tinc0.nas.chn.moe"; }
        )
      )
    )
    # vps6 -> pc
    (lib.mkIf (config.nixos.model.hostname == "vps6") {
      "xn--qbtm095lrg0bfka60z.chn.moe".upstream.address = "tinc0.pc.chn.moe";
    })
  ];
}
