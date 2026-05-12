{ lib, config, pkgs, ... }:
{
  options.nixos.services.hongbao = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) hongbao; in lib.mkIf (hongbao != null)
  {
    nixos.services =
    {
      phpfpm.instances.hongbao = {};
      nginx.https =
      {
        "zzzhongbao2026.chn.moe".location =
        {
          "/".return.return = "400";
          "/index.php".php =
          {
            root = "/srv/hongbao";
            fastcgiPass = config.nixos.services.phpfpm.instances.hongbao.fastcgi;
          };
        };
        "hongbao2026.chn.moe".location =
          let cppfile = pkgs.writeTextDir "index.cpp.txt"
          ''
            # include <iostream>
            # include <crystal>
            # include <httplib.h>
            int main()
            {
              int id = crystals.allCrystal()
                | filter([](auto &c) { return c.name == "SiC" && c.primitiveCell.atomNumber == 8; })
                | map([](auto &c) { return c.spaceGroup; })
                | get(0);
              httplib::Client cli("https://zzzhongbao2026.chn.moe");
              auto answer = cli.Get("/index.php?id=" + std::to_string(id));
              std::cout << answer->body;
            }
          '';
          in
          {
            "/".return.return = "302 https://hongbao2026.chn.moe/index.cpp.txt";
            "/index.cpp.txt".static.root = cppfile.outPath;
          };
      };
    };
    systemd.tmpfiles.rules = [ "d /srv/hongbao 0700 hongbao hongbao" "Z /srv/hongbao - hongbao hongbao" ];
  };
}
