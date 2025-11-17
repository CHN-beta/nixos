inputs:
{
  options.nixos.system.sops = let inherit (inputs.lib) mkOption types; in
  {
    secrets = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        path = mkOption
        {
          type = types.path;
          default = inputs.config.sops.secrets.${submoduleInputs.config._module.args.name}.path;
          readOnly = true;
        };
        key = mkOption { type = types.str; default = submoduleInputs.config._module.args.name; };
        format = mkOption { type = types.enum [ "yaml" "binary" ]; default = "yaml"; };
        mode = mkOption { type = types.str; default = "0400"; };
        owner = mkOption { type = types.nullOr types.str; default = null; };
        group = mkOption { type = types.nullOr types.str; default = null; };
        sopsFile = mkOption
        {
          type = types.path;
          default =
            let secretFileIndex =
              inputs.lib.lists.findFirstIndex (x: x) null
              (builtins.map
                (file: inputs.lib.hasAttrByPath (inputs.lib.splitString "/" submoduleInputs.config.key)
                  (inputs.pkgs.localPackages.fromYaml (builtins.readFile file)))
                inputs.config.nixos.system.sops.defaultSopsFile);
            in
              if secretFileIndex == null then builtins.abort "No sops file found for ${submoduleInputs.config.key}"
              else builtins.elemAt inputs.config.nixos.system.sops.defaultSopsFile secretFileIndex;
        };
        neededForUsers = mkOption { type = types.bool; default = false; };
      };}));
      default = {};
    };
    templates = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        content = mkOption { type = types.str; };
        path = mkOption
        {
          type = types.path;
          default = inputs.config.sops.templates.${submoduleInputs.config._module.args.name}.path;
          readOnly = true;
        };
        owner = mkOption { type = types.nullOr types.str; default = null; };
        group = mkOption { type = types.nullOr types.str; default = null; };
        mode = mkOption { type = types.str; default = "0400"; };
        file = mkOption
        {
          type = types.path;
          default = inputs.config.sops.templates.${submoduleInputs.config._module.args.name}.file;
          readOnly = true;
        };
      };}));
      default = {};
    };
    # define default in config
    placeholder = mkOption { type = types.attrsOf types.str; };
    defaultSopsFile = mkOption
    {
      type = types.nonEmptyListOf types.path;
      readOnly = true;
      default =
        let
          defaultSopsFile = path:
            if builtins.pathExists "${path}/secrets.yaml" then [ "${path}/secrets.yaml" ]
            else if builtins.pathExists "${path}/secrets/default.yaml" then [ "${path}/secrets/default.yaml" ]
            else [];
          devicePath =  "${inputs.topInputs.self}/devices";
          inherit (inputs.config.nixos) model;
        in
          []
          ++ (inputs.lib.optionals (model.cluster == null) (defaultSopsFile "${devicePath}/${model.hostname}"))
          ++ (inputs.lib.optionals (model.cluster != null)
            (
              (defaultSopsFile "${devicePath}/${model.cluster.clusterName}/${model.cluster.nodeName}")
                ++ (defaultSopsFile "${devicePath}/${model.cluster.clusterName}")
            ))
          ++ (defaultSopsFile "${devicePath}/cross")
          ++ [ "${devicePath}/cross/secrets/chn.yaml" "${devicePath}/cross/secrets/xray-server.yaml" ];
    };
    availableKeys = mkOption
    {
      type = types.listOf (types.listOf types.str);
      readOnly = true;
      default =
        let getPath = x:
          if builtins.typeOf x == "string" then [[]]
          else if builtins.typeOf x == "set"
            then builtins.concatLists (inputs.lib.mapAttrsToList (n: v: builtins.map (l: [ n ] ++ l) (getPath v)) x)
          # simply ignore list, they are sops metadata
          else if builtins.typeOf x == "list" then [[]]
          else builtins.abort "Invalid type for availableKeys, get type ${builtins.typeOf x}";
        in builtins.concatLists (builtins.map
          (f: getPath (inputs.pkgs.localPackages.fromYaml (builtins.readFile f)))
          inputs.config.nixos.system.sops.defaultSopsFile);
    };
  };
  config =
  {
    nixos.system.sops.placeholder = builtins.mapAttrs
      (n: _: inputs.lib.mkOptionDefault "sops${builtins.hashString "sha256" n}sops")
      inputs.config.nixos.system.sops.secrets;
    sops =
    {
      secrets = builtins.mapAttrs
        (n: v: { inherit (v) key format mode owner group sopsFile neededForUsers; })
        inputs.config.nixos.system.sops.secrets;
      templates = builtins.mapAttrs
        (n: v: { inherit (v) content owner group mode; })
        inputs.config.nixos.system.sops.templates;
      inherit (inputs.config.nixos.system.sops) placeholder;
      age.sshKeyPaths = [ "/nix/persistent/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
}
