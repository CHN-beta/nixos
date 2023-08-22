{ lib, stdenv, mkPnpmPackage, fetchFromGitHub, nodejs }:
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
	originalPnpmPackage = mkPnpmPackage { inherit pname version src nodejs; };
in stdenv.mkDerivation
{
	inherit pname version src;
	nodeModules = originalPnpmPackage.nodeModules.overrideAttrs { PUPPETEER_SKIP_DOWNLOAD = true; };
	configurePhase = 
	''
		export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
		export npm_config_nodedir=${nodejs}

		runHook preConfigure

		${if installInPlace
			then passthru.nodeModules.buildPhase
			else ''
				${if !copyNodeModules
					then "ln -s"
					else "cp -r"
				} ${passthru.nodeModules}/. node_modules
			''
		}

		runHook postConfigure
	'';
}
