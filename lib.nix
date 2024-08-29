lib: rec
{
  attrsToList = attrs: builtins.map (name: { inherit name; value = attrs.${name}; }) (builtins.attrNames attrs);
  mkConditional = condition: trueResult: falseResult: let inherit (lib) mkMerge mkIf; in
    mkMerge [ ( mkIf condition trueResult ) ( mkIf (!condition) falseResult ) ];

  # Behaviors of these two NixOS modules would be different:
  # { pkgs, ... }@inputs: { environment.systemPackages = [ pkgs.hello ]; }
  # inputs: { environment.systemPackages = [ pkgs.hello ]; }
  # The second one would failed to evaluate because nixpkgs would not pass pkgs to it.
  # So that we wrote a wrapper to make it always works like the first one.
  mkModules = moduleList:
    (builtins.map
      (
        let handle = module: let type = builtins.typeOf module; in
          if type == "path" || type == "string" then (handle (import module))
          else if type == "lambda" then ({ pkgs, utils, ... }@inputs: (module inputs))
          else module;
        in handle
      )
      moduleList);

  # from: https://github.com/NixOS/nix/issues/3759
  stripeTabs = text:
    let
      # Whether all lines start with a tab (or is empty)
      shouldStripTab = lines: builtins.all (line: (line == "") || (lib.strings.hasPrefix "  " line)) lines;
      # Strip a leading tab from all lines
      stripTab = lines: builtins.map (line: lib.strings.removePrefix "  " line) lines;
      # Strip tabs recursively until there are none
      stripTabs = lines: if (shouldStripTab lines) then (stripTabs (stripTab lines)) else lines;
    in
      # Split into lines. Strip leading tabs. Concat back to string.
      builtins.concatStringsSep "\n" (stripTabs (lib.strings.splitString "\n" text));
  
  # find an element in a list, return the index
  findIndex = e: list:
    let findIndex_ = i: list: if (builtins.elemAt list i) == e then i else findIndex_ (i + 1) list;
    in findIndex_ 0 list;

  # return a list of path, including:
  # - all .nix file in the directory except for default.nix
  # - all directories containing a default.nix
  findModules = path:
    mkModules (builtins.filter (path: path != null) (builtins.map
      (subPath:
        if subPath.value == "regular" && subPath.name != "default.nix"
          then if lib.strings.hasSuffix ".nix" subPath.name
            then "${path}/${subPath.name}"
            else null
          else if subPath.value == "directory"
            then if (builtins.readDir "${path}/${subPath.name}")."default.nix" or null == "regular"
              then "${path}/${subPath.name}"
            else null
          else null)
      (attrsToList (builtins.readDir path))));

  # replace the value in a nested attrset. example:
  # deepReplace
  #   [ { path = [ "a" "b" 1 ]; value = "new value"; } ]
  #   { a = { b = [ "old value" "old value" ]; }; }
  # => { a = { b = [ "old value" "new value" ]; }; }
  deepReplace = pattern: origin:
    let replace = { path, value, content }:
      if path == [] then
        if (builtins.typeOf value) == "lambda" then value content
        else value
      else let currentPath = builtins.head path; nextPath = builtins.tail path; in
        if (builtins.typeOf currentPath) == "string" then
          if (builtins.typeOf content) != "set" then builtins.throw "content should be a set"
          else builtins.mapAttrs
            (n: v: if n == currentPath then replace { path = nextPath; inherit value; content = v; } else v) content
        else if (builtins.typeOf currentPath) == "int" then
          if (builtins.typeOf content) != "list" then builtins.throw "content should be a list"
          else lib.imap0
            (i: v: if i == currentPath then replace { path = nextPath; inherit value; content = v; } else v) content
        else if (builtins.typeOf currentPath) != "lambda" then throw "path should be a lambda"
        else
          if (builtins.typeOf content) == "list" then builtins.map
            (v: if currentPath v then replace { path = nextPath; inherit value; content = v; } else v) content
          else if (builtins.typeOf content) == "set" then builtins.listToAttrs (builtins.map
            (v: if currentPath v then replace { path = nextPath; inherit value; content = v; } else v)
            (attrsToList content))
          else throw "content should be a list or a set.";
    in
      if (builtins.typeOf pattern) != "list" then throw "pattern should be a list"
      else if pattern == [] then origin
      else deepReplace (builtins.tail pattern) (replace ((builtins.head pattern) // { content = origin; }));
}
