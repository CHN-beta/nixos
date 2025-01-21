{
  src, buildPythonPackage, setuptools,
  requests, octodns, dnspython
}:
buildPythonPackage
{
  name = "octodns-cloudflare";
  pyproject = true;
  inherit src;
  nativeBuildInputs = [ setuptools ];
  propagatedBuildInputs = [ octodns dnspython requests ];
  env.OCTODNS_RELEASE = 1;
}
