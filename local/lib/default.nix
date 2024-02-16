lib:
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
        let handle = module:
          if ( builtins.typeOf module ) == "path" then (handle (import module))
          else if ( builtins.typeOf module ) == "lambda" then ({ pkgs, utils, ... }@inputs: (module inputs))
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
}
