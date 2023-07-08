Attrs: builtins.map ( name: { inherit name; value = Attrs.${name}; } ) ( builtins.attrNames Attrs )
