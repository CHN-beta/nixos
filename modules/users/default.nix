inputs:
{
  imports = inputs.localLib.mkModules (builtins.map (dir: ././${dir.name})
    (builtins.filter (dir: dir.value == "directory") (inputs.localLib.attrsToList (builtins.readDir ./.))));
  options.nixos.users = let inherit (inputs.lib) mkOption types; in
  {
    users = mkOption { type = types.listOf types.nonEmptyStr; default = [ "chn" ]; };
    sharedModules = mkOption { type = types.listOf types.anything; default = []; };
  };
  config =
    let
      inherit (inputs.config.nixos) users;
      inherit (builtins) map;
      inherit (inputs.lib) mkMerge;
    in
    {
      users = mkMerge (map
        (name:
        {
          users.${name} =
          {
            uid = inputs.config.nixos.system.user.user.${name};
            group = name;
            isNormalUser = true;
          };
          groups.${name}.gid = inputs.config.nixos.system.user.group.${name};
        })
        users.users);
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
