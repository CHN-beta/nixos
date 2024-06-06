inputs:
{
  options.nixos.services.meilisearch = let inherit (inputs.lib) mkOption types; in
  {
    instances = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        port = mkOption { type = types.ints.unsigned; };
      };}));
      default = {};
    };
    ioLimitDevice = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
  };
  config = let inherit (inputs.config.nixos.services) meilisearch; in
  {
    systemd =
    {
      services = builtins.listToAttrs (builtins.map
        (instance:
        {
          name = "meilisearch-${instance.name}";
          value =
          {
            description = "meiliSearch ${instance.name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            # environment.RUST_BACKTRACE = "full";
            serviceConfig =
            {
              User = instance.value.user;
              Group = inputs.config.users.users.${instance.value.user}.group;
              ExecStart =
                let
                  meilisearch = inputs.pkgs.meilisearch.overrideAttrs (prev:
                  {
                    RUSTFLAGS = prev.RUSTFLAGS or [] ++ [ "-Clto=true" "-Cpanic=abort" "-Cembed-bitcode=yes"]
                      ++ (
                        let inherit (inputs.config.nixos.system.nixpkgs) march;
                        in (if march != null then [ "-Ctarget-cpu=${march}" ] else [])
                      );
                  });
                  config = inputs.config.sops.templates."meilisearch-${instance.name}.toml".path;
                in
                  "${meilisearch}/bin/meilisearch --config-file-path ${config}";
              Restart = "always";
              StartLimitBurst = 3;
              LimitNOFILE = "infinity";
              LimitNPROC = "infinity";
              LimitCORE = "infinity";
              CPUSchedulingPolicy = "idle";
              IOSchedulingClass = "idle";
              IOSchedulingPriority = 4;
              IOAccounting = true;
              IOWeight = 1;
              Nice = 19;
              Slice = "-.slice";
            }
            // (if meilisearch.ioLimitDevice != null then
            {
              IOReadBandwidthMax = "${meilisearch.ioLimitDevice} 20M";
              IOWriteBandwidthMax = "${meilisearch.ioLimitDevice} 20M";
              # iostat -dx 1
              IOReadIOPSMax = "${meilisearch.ioLimitDevice} 100";
              IOWriteIOPSMax = "${meilisearch.ioLimitDevice} 100";
            } else {});
          };
        })
        (inputs.localLib.attrsToList meilisearch.instances));
      tmpfiles.rules = builtins.concatLists (builtins.map
        (instance:
          let
            user = instance.value.user;
            group = inputs.config.users.users.${instance.value.user}.group;
            dir = "/var/lib/meilisearch/${instance.name}";
          in
            [ "d ${dir} 0700 ${user} ${group}" "Z ${dir} - ${user} ${group}" ])
        (inputs.localLib.attrsToList meilisearch.instances));
    };
    sops =
    {
      templates = builtins.listToAttrs (builtins.map
        (instance:
        {
          name = "meilisearch-${instance.name}.toml";
          value =
          {
            content =
            ''
              db_path = "/var/lib/meilisearch/${instance.name}"
              http_addr = "0.0.0.0:${builtins.toString instance.value.port}"
              master_key = "${inputs.config.sops.placeholder."meilisearch/${instance.name}"}"
              env = "production"
              dump_dir = "/var/lib/meilisearch/${instance.name}/dumps"
              log_level = "INFO"
              max_indexing_memory = "16Gb"
              max_indexing_threads = 1
            '';
            owner = instance.value.user;
          };
        })
        (inputs.localLib.attrsToList meilisearch.instances));
      secrets = builtins.listToAttrs (builtins.map
        (instance: { name = "meilisearch/${instance.name}"; value = {}; })
        (inputs.localLib.attrsToList meilisearch.instances));
    };
    environment.persistence =
      let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
        { "${impermanence.nodatacow}".directories = [ "/var/lib/meilisearch" ]; };
  };
}
