{ lib, mkPnpmPackage, fetchFromGitHub }:
mkPnpmPackage
{
  src = fetchFromGitHub
	{
		owner = "DIYgod";
		repo = "RSSHub";
		rev = "ecab0c0882a17b9b70431aca0c155a2da9d2c4fa";
		hash = "sha256-VAIUQCQcKYaav4Ch73Cn7poO0/VCGtWkWJkPJ3Qp31A=";
	};
	nodeModulesPreBuild = "export PUPPETEER_SKIP_DOWNLOAD=true";
	script = "build:all";
}
