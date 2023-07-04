{
	lib, fetchPypi, buildPythonPackage,
	numpy, pillow, wxPython_4_2, matplotlib, ipython, pyopengl
}: buildPythonPackage rec
{
	pname = "spectral";
	version = "0.23.1";
	src = fetchPypi
	{
		inherit pname version;
		sha256 = "sha256-4YIic1Je81g7J6lmIm1Vr+CefSmnI2z82LwN+x+Wj8I=";
	};
	doCheck = false;
	propagatedBuildInputs = [ numpy pillow wxPython_4_2 matplotlib ipython pyopengl ];
}
