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
  };
  config =
    let
      inherit (inputs.config.nixos.services) meilisearch;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (builtins) map listToAttrs;
    in
    {
      systemd =
      {
        services = listToAttrs (map
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
                    meilisearch = inputs.pkgs.unstablePackages.meilisearch.overrideAttrs (prev:
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
              };
            };
          })
          (attrsToList meilisearch.instances));
        tmpfiles.rules = map
          (instance:
            let
              user = instance.value.user;
              group = inputs.config.users.users.${instance.value.user}.group;
            in
              "d /var/lib/meilisearch/${instance.name} 0700 ${user} ${group}")
          (attrsToList meilisearch.instances);
      };
      sops =
      {
        templates = listToAttrs (map
          (instance:
          {
            name = "meilisearch-${instance.name}.toml";
            value =
            {
              content =
              ''
                db_path = "/var/lib/meilisearch/${instance.name}"
                http_addr = "0.0.0.0:${toString instance.value.port}"
                master_key = "${inputs.config.sops.placeholder."meilisearch/${instance.name}"}"
                env = "production"
                dump_dir = "/var/lib/meilisearch/${instance.name}/dumps"
                log_level = "INFO"
                max_indexing_memory = "8Gb"
                max_indexing_threads = 1
              '';
              owner = inputs.config.users.users.misskey.name;
            };
          })
          (attrsToList meilisearch.instances));
        secrets = listToAttrs (map
          (instance: { name = "meilisearch/${instance.name}"; value = {}; })
          (attrsToList meilisearch.instances));
      };
    };
}
