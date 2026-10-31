{
  lib,
  python3Packages,
  cups,
}:
python3Packages.buildPythonApplication {
  pname = "g1010-tool";
  version = "0.1.0";
  pyproject = false;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${./g1010-tool.py} $out/bin/g1010-tool
    runHook postInstall
  '';

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ cups ]}"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    $out/bin/g1010-tool --help > /dev/null
    $out/bin/g1010-tool nozzle --stdout | grep -q '<ivec:operation>TestPrint</ivec:operation>'
    $out/bin/g1010-tool clean --group black --stdout | grep -q '<ivec:inkgroup>group1</ivec:inkgroup>'
    $out/bin/g1010-tool deep-clean --stdout | grep -q '<ivec:type>deep</ivec:type>'
    $out/bin/g1010-tool flush --yes --stdout | grep -q '<ivec:type>choke</ivec:type>'
    $out/bin/g1010-tool roller --stdout | grep -q '<ivec:operation>RollerCleaning</ivec:operation>'
    runHook postCheck
  '';

  meta = {
    description = "Canon PIXMA G1010 printhead maintenance CLI tool (IVEC XML protocol)";
    license = lib.licenses.gpl3Plus;
    mainProgram = "g1010-tool";
    platforms = lib.platforms.linux;
  };
}
