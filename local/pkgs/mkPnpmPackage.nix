{ lib, remarshal, fetchurl, runCommand, nodejs, stdenv, pkg-config, writeText }:
  {
    src,
    lockFile ? "${src}/pnpm-lock.yaml",
    packageFile ? "${src}/package.json",
    pname ? (builtins.fromJSON (builtins.readFile packageFile)).name,
    version ? (builtins.fromJSON (builtins.readFile packageFile)).version or null,
    extraIntegritySha256 ? {},
    registry ? "https://registry.npmjs.org",
    extraNativeBuildInputs ? [],
    buildScript ? "build",
    extraAttrs ? {},
  }:
    let
      originalLock = builtins.fromJSON
        (builtins.readFile (runCommand "toJSON" { } "${remarshal}/bin/yaml2json ${lockFile} $out"));
      patchedLock = originalLock
      // {
        packages = lib.mapAttrs
          (name: value:
            if (value.resolution ? integrity) == (value.resolution ? tarball)
              then throw "could not determine source ${name}"
            else if value.resolution ? integrity then
              # name maybe /@vue/compiler-core@3.4.18 or @vue/compiler-core@3.4.18
              #   or /@storybook/core-server@8.0.0-beta.6(react-dom@18.2.0)(react@18.2.0)
              let nameAtVersion = builtins.head (lib.splitString "(" name);
              in let
                version = lib.last (lib.splitString "@" nameAtVersion);
                name = lib.last (lib.init (lib.splitString "@" nameAtVersion));
                baseName = lib.last (lib.splitString "/" name);
                url = "${registry}/${name}/-/${baseName}-${version}.tgz";
                tarball = fetchurl { inherit url; sha512 = value.resolution.integrity; };
              in value // { resolution.tarball = "file:${tarball}"; }
            else # if value.resolution ? tarball then
              if lib.hasPrefix "https://codeload.github.com" value.resolution.tarball then
                let
                  match = lib.strings.match
                    "https://codeload.github.com/([^/]+)/([^/]+)/tar\\.gz/([a-f0-9]+)" value.resolution.tarball;
                  repo = fetchGit
                  {
                    url = "https://github.com/${builtins.elemAt match 0}/${builtins.elemAt match 1}";
                    rev = builtins.elemAt match 2;
                    shallow = true;
                  };
                  tarball = runCommand "${builtins.elemAt match 1}.tgz" {} "tar -czf $out -C ${repo} .";
                in value // { resolution.tarball = "file:${tarball}"; }
              else
                let tarball = fetchurl rec
                  { url = value.resolution.tarball; sha256 = extraIntegritySha256.${url}; };
                in value // { resolution.tarball = "file:${tarball}"; }
          )
          originalLock.packages;
      };
      patchedLockFile = writeText "pnpm-lock.yaml" (builtins.toJSON patchedLock);
    in stdenv.mkDerivation
    ({
      inherit src pname version;
      nativeBuildInputs = [ nodejs nodejs.pkgs.pnpm pkg-config ] ++ extraNativeBuildInputs;

      configurePhase =
      ''
        runHook preConfigure
        export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
        export npm_config_nodedir=${nodejs}
        pnpm config set reporter append-only
        cp -f ${patchedLockFile} pnpm-lock.yaml
        runHook postConfigure
      '';

      buildPhase =
        ''
          runHook preBuild
          pnpm install --frozen-lockfile --offline
          pnpm run ${buildScript}
          runHook postBuild
        '';

      installPhase =
      ''
        runHook preInstall
        mkdir -p $out
        mv * .* $out
        runHook postInstall
      '';
    } // extraAttrs)
