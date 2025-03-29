{
  src, crack, stdenv, autoPatchelfHook,
  xorg, libz, glib, freetype, alsa-lib, nspr, at-spi2-atk, nss, gtk3, libdrm, mesa
}: stdenv.mkDerivation
{
  name = "lumericalLicenseManager";
  buildInputs = [ stdenv.cc.cc.lib libz glib freetype alsa-lib nspr at-spi2-atk nss gtk3 libdrm mesa ]
    ++ (with xorg; [ libX11 libICE libXcomposite libXcursor libXdamage libXext libXfixes libXtst libXScrnSaver ]);
  nativeBuildInputs = [ autoPatchelfHook ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase =
  ''
    mkdir -p $out/v231
    tar -xf ${src}/clclient/LINX64.TGZ -C $out/v231
    tar -xf ${src}/license/LINX64.TGZ -C $out
    tar -xf ${src}/licserv/LINX64.TGZ -C $out
    tar -xf ${src}/lmcenter/LINX64.TGZ -C $out
    cp -r ${crack}/ansys_inc/* $out

    chmod +x $out/shared_files/bin/linx64/*
    chmod +x $out/shared_files/licensing/lic_admin/bin/*
    chmod +x $out/shared_files/licensing/linx64/*
    chmod +x $out/shared_files/licensing/tools/bin/*
    chmod +x $out/shared_files/licensing/tools/bin/linx64/*
    chmod +x $out/shared_files/licensing/tools/java/linx64/bin/*
    chmod +x $out/shared_files/licensing/tools/tomcat/bin/*

    rm -r $out/shared_files/licensing/license_files
    ln -s /var/lib/lumerical/license_files $out/shared_files/licensing/license_files
    chmod -R +w $out/shared_files/licensing/tools/tomcat
    rm -r $out/shared_files/licensing/tools/tomcat/logs
    ln -s /var/log/lumerical/tomcat-log $out/shared_files/licensing/tools/tomcat/logs
    rm $out/shared_files/licensing/tools/tomcat/bin/setenv.sh.old

    sed -i "s|/home/ansys_inc|$out|g" $out/shared_files/licensing/tools/tomcat/bin/setenv.sh $out/shared_files/licensing/init_ansysli $out/shared_files/licensing/init_ansyslm_tomcat

    # openldap 2.4 no longer exists
    patchelf --remove-needed liblber-2.4.so.2 $out/shared_files/licensing/linx64/update/ansysli_util
    patchelf --remove-needed libldap-2.4.so.2 $out/shared_files/licensing/linx64/update/ansysli_util
  '';
}
