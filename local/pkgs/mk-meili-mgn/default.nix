{ lib, fetchFromGitHub, rustPlatform, pkg-config, openssl }:
rustPlatform.buildRustPackage rec
{
	pname = "mk-meili-mgn";
	version = "20230806";
	src = fetchFromGitHub
	{
		owner = "libnare";
		repo = "mk-meili-mgn";
		rev = "e5995980519ec4aa25b73dac5dd010d2e041b1e5";
		hash = "sha256-WFX1dFMYdNH2Aswf87KvmdcNNG3+cdLMRB80Y3yJDMQ=";
	};
	cargoHash = "sha256-i1+0tqRW8uXfaXZbMHrOnppFfOLCi8Df5bF7k5IsNwk=";
	nativeBuildInputs = [ pkg-config ];
	buildInputs = [ openssl ];
}
