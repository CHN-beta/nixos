inputs:
{
  options.nixos.services.hpcstat = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) hpcstat; in inputs.lib.mkIf (hpcstat != null)
  {
    systemd =
    {
      services.hpcstat =
      {
        script =
          let
            rsync = "${inputs.pkgs.rsync}/bin/rsync";
            grep = "${inputs.pkgs.gnugrep}/bin/grep";
            curl = "${inputs.pkgs.curl}/bin/curl";
            cat = "${inputs.pkgs.coreutils}/bin/cat";
            token = inputs.config.sops.secrets."telegram/token".path;
            chat = inputs.config.sops.secrets."telegram/chat".path;
            date = "${inputs.pkgs.coreutils}/bin/date";
            hpcstat = "${inputs.pkgs.localPackages.hpcstat}/bin/hpcstat";
            ssh = "${inputs.pkgs.openssh}/bin/ssh -i ${key} -o StrictHostKeyChecking=no"
              + " -o ForwardAgent=yes -o AddKeysToAgent=yes";
            key = inputs.config.sops.secrets."hpcstat/key".path;
            jykang = "${inputs.topInputs.self}/devices/jykang.xmuhpc";
            ssh-agent = "${inputs.pkgs.openssh}/bin/ssh-agent";
          in
          ''
            eval $(${ssh-agent})
            # check if the file content differ
            if ${rsync} -e "${ssh}" -acnri ${jykang}/ jykang@hpc.xmu.edu.cn:~/ | ${grep} -E '^[<>]' -q; then
              ${curl} -X POST -H 'Content-Type: application/json' \
                -d "{\"chat_id\": \"$(${cat} ${chat})\", \"text\": \"File content differ!\"}" \
                https://api.telegram.org/bot$(${cat} ${token})/sendMessage
              exit 1
            fi
            # check finishjob
            ${ssh} jykang@hpc.xmu.edu.cn hpcstat finishjob
            ${ssh} jykang@hpc.xmu.edu.cn hpcstat push
            # download database
            now=$(${date} '+%Y%m%d%H%M%S')
            ${rsync} -e "${ssh}" \
              jykang@hpc.xmu.edu.cn:~/linwei/chn/software/hpcstat/var/lib/hpcstat/hpcstat.db \
              /var/lib/hpcstat/hpcstat.db.$now
            if [ $? -ne 0 ]; then
              ${curl} -X POST -H 'Content-Type: application/json' \
                -d "{\"chat_id\": \"$(${cat} ${chat})\", \"text\": \"Download database failed!\"}" \
                https://api.telegram.org/bot$(${cat} ${token})/sendMessage
              exit 1
            fi
            # diff database
            if [ -f /var/lib/hpcstat/hpcstat.db.last ]; then
              ${hpcstat} verify /var/lib/hpcstat/hpcstat.db.last /var/lib/hpcstat/hpcstat.db.$now
            fi
            if [ $? -ne 0 ]; then
              ${curl} -X POST -H 'Content-Type: application/json' \
                -d "{\"chat_id\": \"$(${cat} ${chat})\", \"text\": \"Database verification failed!\"}" \
                https://api.telegram.org/bot$(${cat} ${token})/sendMessage
              exit 1
            fi
            # update database
            ln -sf hpcstat.db.$now /var/lib/hpcstat/hpcstat.db.last
          '';
        serviceConfig = { Type = "oneshot"; User = "hpcstat"; Group = "hpcstat"; };
      };
      timers.hpcstat =
      {
        wantedBy = [ "timers.target" ];
        timerConfig = { OnCalendar = "*-*-* *:00/5:00"; Unit = "hpcstat.service"; };
      };
      tmpfiles.rules = [ "d /var/lib/hpcstat 0700 hpcstat hpcstat" ];
    };
    sops.secrets =
    {
      "telegram/token" = { group = "telegram"; mode = "0440"; };
      "telegram/chat" = { group = "telegram"; mode = "0440"; };
      "hpcstat/key" = { owner = "hpcstat"; group = "hpcstat"; };
    };
    users =
    {
      users.hpcstat =
      {
        uid = inputs.config.nixos.user.uid.hpcstat;
        group = "hpcstat";
        extraGroups = [ "telegram" ];
        isSystemUser = true;
      };
      groups =
      {
        hpcstat.gid = inputs.config.nixos.user.gid.hpcstat;
        telegram.gid = inputs.config.nixos.user.gid.telegram;
      };
    };
  };
}
