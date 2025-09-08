{ runCommand, src, rpm, unzip, autoPatchelfHook, cups }: runCommand "huawei-pixlab-series"
{
  buildInputs = [ autoPatchelfHook ];
  nativeBuildInputs = [ rpm unzip cups ];
}
''
  unzip ${src.src} -d .
  unzip huawei-pixlab-series_${src.version}_x64/huawei-pixlab-series_${src.version}_x64.zip -d .
  rpm2archive huawei-pixlab-series_${src.version}_x64/x86_64/huawei-pixlab-series-${src.version}.x86_64.rpm
  tar -xf huawei-pixlab-series_${src.version}_x64/x86_64/huawei-pixlab-series-${src.version}.x86_64.rpm.tgz
  mkdir -p $out/
  cp -r etc usr/share usr/lib $out
  export autoPatchelfIgnoreMissingDeps=1
  autoPatchelf $out
''

