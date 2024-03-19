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
  config = let inherit (inputs.config.nixos) user; in
  {
    users = inputs.lib.mkMerge (builtins.map
      (name:
      {
        users.${name} =
        {
          uid = inputs.config.nixos.user.uid.${name};
          group = name;
          isNormalUser = true;
        };
        groups.${name}.gid = inputs.config.nixos.user.gid.${name};
      })
      user.users);
  };
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
