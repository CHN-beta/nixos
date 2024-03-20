inputs:
{
  imports = inputs.localLib.mkModules (inputs.localLib.findModules ./.);
  options.nixos.user = let inherit (inputs.lib) mkOption types; in
  {
    users = mkOption { type = types.listOf types.nonEmptyStr; default = [ "chn" ]; };
    sharedModules = mkOption { type = types.listOf types.anything; default = []; };
    uid = mkOption
    {
      type = types.attrsOf types.ints.unsigned;
      readOnly = true;
      default =
      {
        chn = 1000;
        xll = 1001;
        yjq = 1002;
        yxy = 1003;
        zem = 1004;
        gb = 1005;
        test = 1006;
        misskey-misskey = 2000;
        misskey-misskey-old = 2001;
        frp = 2002;
        mirism = 2003;
        httpapi = 2004;
        httpua = 2005;
        rsshub = 2006;
        v2ray = 2007;
        fz-new-order = 2008;
        synapse-synapse = 2009;
        synapse-matrix = 2010;
      };
    };
    gid = mkOption
    {
      type = types.attrsOf types.ints.unsigned;
      readOnly = true;
      default = inputs.config.nixos.user.uid //
      {
        groupshare = 3000;
      };
    };
  };
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkMerge
  [
    {
      users =
      {
        users = builtins.listToAttrs (builtins.map
          (userName:
          {
            name = userName;
            value =
            {
              uid = user.uid.${userName};
              group = userName;
              isNormalUser = true;
              shell = inputs.pkgs.zsh;
              extraGroups = inputs.lib.intersectLists [ "users" "video" "audio" ]
                (builtins.attrNames inputs.config.users.groups);
              # ykman fido credentials list
              # ykman fido credentials delete f2c1ca2d
              # ssh-keygen -t ed25519-sk -O resident
              # ssh-keygen -K
              openssh.authorizedKeys.keys =
                let
                  keys = [ "rsa" "ed25519" "ed25519_sk" ];
                  getKey = user: key: inputs.lib.optional (builtins.pathExists ./${user}/id_${key}.pub)
                    (builtins.readFile ./${user}/id_${key}.pub);
                in inputs.lib.mkDefault (builtins.concatLists (builtins.map (key: getKey userName key) keys));
            };
          })
          user.users);
        groups = builtins.listToAttrs (builtins.map
          (name: { inherit name; value.gid = user.gid.${name}; })
          user.users);
      };
      home-manager.users = builtins.listToAttrs (builtins.map
        (name: { inherit name; value.imports = user.sharedModules; })
        user.users);
    }
    {
      users.users.root.openssh.authorizedKeys.keys = [(builtins.readFile ./chn/id_ed25519_sk.pub)];
    }
  ];
}

# environment.persistence."/impermanence".users.chn =
# {
#   directories =
#   [
#     "Desktop"
#     "Documents"
#     "Downloads"
#     "Music"
#     "repo"
#     "Pictures"
#     "Videos"

#     ".cache"
#     ".config"
#     ".gnupg"
#     ".local"
#     ".ssh"
#     ".android"
#     ".exa"
#     ".gnome"
#     ".Mathematica"
#     ".mozilla"
#     ".pki"
#     ".steam"
#     ".tcc"
#     ".vim"
#     ".vscode"
#     ".Wolfram"
#     ".zotero"

#   ];
#   files =
#   [
#     ".bash_history"
#     ".cling_history"
#     ".gitconfig"
#     ".gtkrc-2.0"
#     ".root_hist"
#     ".viminfo"
#     ".zsh_history"
#   ];
# };
