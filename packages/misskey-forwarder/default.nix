{ lib, stdenv, cmake, pkg-config, biu, configFile ? null, httplib }: stdenv.mkDerivation
{
  name = "misskey-forwarder";
  src = ./.;
  buildInputs = [ biu httplib ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optional (configFile != null) [ "-DFORWARDER_CONFIG_FILE=${configFile}" ];
}
