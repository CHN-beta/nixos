{
  src,
  crack,
  buildFHSEnv,
  stdenvNoCC,
  writeScript,
  licenseFile ? "/tmp/lumerical-license",
}:
let
  builder = buildFHSEnv {
    name = "builder";
    targetPkgs =
      pkgs: with pkgs; [
        coreutils
        glib
      ];
    extraBwrapArgs = [
      "--bind"
      "$out"
      "$out"
    ];
  };
  package = stdenvNoCC.mkDerivation {
    name = "lumericalLicenseManager";
    dontUnpack = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p $out
      cp -r ${src}/* .
      chmod +x ./INSTALL
      ${builder}/bin/builder ./INSTALL -silent -install_dir $out/opt/ansys_inc -lm
      cp -r ${crack}/* $out/opt
      ln -sf ${licenseFile} $out/opt/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic

      # install update
      chmod +w -R $out
      cp -rf $out/opt/ansys_inc/shared_files/licensing/linx64/update/* $out/opt/ansys_inc/shared_files/licensing/linx64
      rm -rf $out/opt/ansys_inc/shared_files/licensing/linx64/update
      cp -rf $out/opt/ansys_inc/shared_files/licensing/tools/update/* $out/opt/ansys_inc/shared_files/licensing/tools
      rm -rf $out/opt/ansys_inc/shared_files/licensing/tools/update

      # fix some log paths, license manager should have write permissions
      rm -rf $out/opt/ansys_inc/shared_files/licensing/tools/tomcat/logs
      ln -s /tmp/lumericalLicenseManager/logs $out/opt/ansys_inc/shared_files/licensing/tools/tomcat/logs
      ln -sf /tmp/lumericalLicenseManager/ansysli_server.log \
        $out/opt/ansys_inc/shared_files/licensing/ansysli_server.log

      # fix env
      sed -i "s|/home/ansys_inc|$out/opt/ansys_inc/shared_files/licensing/../..|g" \
        $out/opt/ansys_inc/shared_files/licensing/tools/tomcat/bin/setenv.sh
      rm $out/opt/ansys_inc/shared_files/licensing/tools/tomcat/bin/setenv.sh.old

      # fix permissions
      chmod +x $out/opt/ansys_inc/shared_files/licensing/tools/tomcat/bin/*
      chmod +x $out/opt/ansys_inc/shared_files/licensing/linx64/*
    '';
  };
  startScript = writeScript "fdtd" ''
    pushd /opt/ansys_inc/shared_files/licensing
    ./start_ansysli &
    ./start_lmcenter &
    tail -f /dev/null
  '';
in
buildFHSEnv {
  name = "lumericalLicenseManager";
  passthru = { inherit builder package; };
  targetPkgs =
    pkgs:
    (with pkgs; [
      coreutils
      glib
    ])
    ++ [ package ];
  runScript = startScript;
}
