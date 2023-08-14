{ lib, mkYarnPackage, fetchFromGitHub }:
mkYarnPackage
{
  pname = "rsshub";
  version = "20230814";
  src = fetchFromGitHub
	{
		owner = "DIYgod";
		repo = "RSSHub";
		rev = "ecab0c0882a17b9b70431aca0c155a2da9d2c4fa";
		hash = "sha256-VAIUQCQcKYaav4Ch73Cn7poO0/VCGtWkWJkPJ3Qp31A=";
	};
	# configurePhase =
	# ''
	# 	cp -r $node_modules node_modules
	# '';
	# buildPhase =
	# ''
	# 	runHook preBuild
	# 	# yarn install --frozen-lockfile --offline
	# 	NODE_ENV=production yarn build --offline
	# 	runHook postBuild
	# '';
}
