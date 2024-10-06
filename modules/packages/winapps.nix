inputs:
{
  options.nixos.packages.winapps = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) winapps; in inputs.lib.mkIf (winapps != null)
  {
    nixos.packages.packages._packages =
    [
      (inputs.pkgs.callPackage "${inputs.topInputs.winapps}/packages/winapps" {})
    ]
      ++ builtins.map
        (p: inputs.pkgs.runCommand "winapps-${p}" {}
        ''
          mkdir -p $out/share/applications
          source ${inputs.topInputs.winapps}/apps/${p}/info
          # replace \ with \\
          WIN_EXECUTABLE=$(echo $WIN_EXECUTABLE | sed 's/\\/\\\\/g')
          # replace space with \s
          WIN_EXECUTABLE=$(echo $WIN_EXECUTABLE | sed 's/ /\\s/g')
          cat > $out/share/applications/${p}.desktop << EOF
          [Desktop Entry]
          Name=$NAME
          Exec=winapps manual "$WIN_EXECUTABLE" %F
          Terminal=false
          Type=Application
          Icon=${inputs.topInputs.winapps}/apps/${p}/icon.svg
          StartupWMClass=$FULL_NAME
          Comment=$FULL_NAME
          Categories=$CATEGORIES
          MimeType=$MIME_TYPES
          EOF
        '')
        [
          "access-o365" "cmd" "excel-o365" "explorer" "illustrator-cc" "powerpoint-o365" "visual-studio-comm"
          "windows" "word-o365"
        ];
  };
}
