{ lib, mkYarnPackage, fetchFromGitHub }:
mkYarnPackage
{
  pname = "misskey";
  version = "13.14.2";
  src = fetchFromGitHub
	{
		owner = "CHN-beta";
		repo = "misskey";
		rev = "8b3920502fd8060e498276c985cd58a0ed86b5df";
		hash = "sha256-P67D2WAcm44CfeSoeD6/kcQP27C59Hm/htD+gmyn8FE=";
		fetchSubmodules = true;
	};
	configurePhase =
	''
		cp -r $node_modules node_modules
	'';
	buildPhase =
	''
		runHook preBuild
		# yarn install --frozen-lockfile --offline
		NODE_ENV=production yarn build --offline
		runHook postBuild
	'';
}
