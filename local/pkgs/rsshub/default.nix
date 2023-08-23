{ lib, stdenv, mkPnpmPackage, fetchFromGitHub, nodejs, writeShellScript, chromium }:
let
	pname = "rsshub";
	version = "20230823";
  src = fetchFromGitHub
	{
		owner = "DIYgod";
		repo = "RSSHub";
		rev = "0352743997ad8c7c137ad9adc767e2c70d143c54";
		hash = "sha256-oqcEZs6XLyz/iUZLhzaj/aO1re/V+hy8ij45Y6L1uKA=";
	};
	originalPnpmPackage = mkPnpmPackage { inherit pname version src nodejs; copyPnpmStore = false; };
	nodeModules = originalPnpmPackage.nodeModules.overrideAttrs { PUPPETEER_SKIP_DOWNLOAD = true; };
	rsshub-unwrapped = stdenv.mkDerivation
	{
		inherit version src;
		pname = "${pname}-unwrapped";
		configurePhase = 
		''
			export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
			export npm_config_nodedir=${nodejs}

			runHook preConfigure

			ln -s ${nodeModules}/. node_modules

			runHook postConfigure
		'';
		installPhase =
		''
			runHook preInstall
			mkdir -p $out
			mv * .* $out
			runHook postInstall
		'';
	};
	startScript = writeShellScript "rsshub"
	''
		cd ${rsshub-unwrapped}
		export CHROMIUM_EXECUTABLE_PATH=${chromium}/bin/chromium
		${nodejs.pkgs.pnpm}/bin/pnpm start
	'';
in stdenv.mkDerivation rec
{
	inherit pname version;
	phases = [ "installPhase" ];
	installPhase =
	''
		runHook preInstall
		mkdir -p $out/bin
		cp ${startScript} $out/bin/rsshub
		runHook postInstall
	'';
}
