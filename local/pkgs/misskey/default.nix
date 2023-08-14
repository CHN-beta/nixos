{ lib, mkYarnPackage, fetchFromGitHub }:
mkYarnPackage
{
  pname = "misskey";
  version = "13.14.2";
  src = fetchFromGitHub
	{
		owner = "CHN-beta";
		repo = "misskey";
		rev = "3a243a2575f3127088c16a4c7fbab669e1c163b0";
		hash = "sha256-/e1UYs/1ovxDovFRLjiiPouC+AIXlvpp7xZQ7iuFHBY=";
		fetchSubmodules = true;
	};
}
