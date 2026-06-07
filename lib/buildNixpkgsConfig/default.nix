# nixpkgsConfig = { march, cuda, nixos, arch, rocm, isKernel310 };
lib: self: nixpkgsConfig:
let
  platformConfig =
    if nixpkgsConfig.march == null then
      { system = "${nixpkgsConfig.arch or "x86_64"}-linux"; }
    else
      {
        ${if nixpkgsConfig.nixos then "hostPlatform" else "localSystem"} = {
          system = "${nixpkgsConfig.arch or "x86_64"}-linux";
          gcc = {
            arch = nixpkgsConfig.march;
            tune = nixpkgsConfig.march;
          };
        };
      };
  cudaConfig = lib.optionalAttrs (nixpkgsConfig.cuda or null != null) (
    (lib.optionalAttrs (nixpkgsConfig.cuda.enableForAllPackages or true) { cudaSupport = true; })
    // (lib.optionalAttrs (nixpkgsConfig.cuda.capabilities != null) {
      cudaCapabilities = nixpkgsConfig.cuda.capabilities;
    })
    // (lib.optionalAttrs (nixpkgsConfig.cuda.forwardCompat != null) {
      cudaForwardCompat = nixpkgsConfig.cuda.forwardCompat;
    })
  );
  cudaOverlay =
    final: prev:
    lib.optionalAttrs (nixpkgsConfig.cuda.capabilities or null != null) {
      # used by cp2k
      cudaTarget =
        nixpkgsConfig.cuda.capabilities |> lib.map (lib.replaceString "." "") |> lib.concatStringsSep ";";
    };
  rocmConfig = lib.optionalAttrs (nixpkgsConfig.rocm or null != null) {
    "${if nixpkgsConfig.rocm.enableForAllPackages or true then "rocmSupport" else null}" = true;
    problems.handlers = lib.genAttrs' (nixpkgsConfig.rocm.targets or [ ]) (
      target: lib.nameValuePair "composable_kernel-${target}" { broken = "ignore"; }
    );
  };
  rocmOverlay =
    final: prev:
    lib.optionalAttrs (nixpkgsConfig.rocm.targets or null != null) {
      rocmPackages = prev.rocmPackages.overrideScope (
        final: prev: { clr = prev.clr.override { localGpuTargets = nixpkgsConfig.rocm.targets; }; }
      );
      # used by cp2k
      "${if nixpkgsConfig.rocm.targets or null != null then "hipTarget" else null}" =
        nixpkgsConfig.rocm.targets |> lib.concatStringsSep ";";
      # cp2k rocm support is currently broken
      cp2k = prev.cp2k.override { gpuBackend = "none"; };
      sirius = prev.sirius.override { gpuBackend = "none"; };
    };
  allowInsecurePredicate =
    p: lib.warn "Allowing insecure package ${p.name or "${p.pname}-${p.version}"}" true;
  genericConfig = {
    inherit allowInsecurePredicate;
    allowUnfree = true;
    android_sdk.accept_license = true;
    # allowBroken = true;
    nvidia.acceptLicense = true;
    microsoftVisualStudioLicenseAccepted = true;
    # allowUnsupportedSystem = true;
  };
  genericOverlay = flake: final: prev: {
    genericPkgs = import flake {
      inherit (final) system;
      config = genericConfig;
    };
  };
  config =
    cudaConfig
    // rocmConfig
    // genericConfig
    // (lib.optionalAttrs (nixpkgsConfig.march != null) {
      oneapiArch =
        let
          match.znver5 = "znver4";
        in
        match.${nixpkgsConfig.march} or nixpkgsConfig.march;
      nvhpcArch = nixpkgsConfig.march;
    });
  overlays = {
    addon = [
      self.inputs.nur-xddxdd.overlays.inSubTree
      self.inputs.buildproxy.overlays.default
      self.inputs.nix4vscode.overlays.default
      self.inputs.bscpkgs.overlays.default
      self.inputs.chinese-fonts.overlays.default
      (final: prev: {
        nur-linyinfeng = (self.inputs.nur-linyinfeng.overlays.default final prev).linyinfeng;
        firefox-addons = (import "${self.inputs.rycee}" { inherit (prev) pkgs; }).firefox-addons;
        dwproton = final.callPackage self.inputs.dwproton { };
        inherit (prev.lib) mkBuildproxy;
        inherit lib;
      })
      self.overlays.default
      rocmOverlay
      cudaOverlay
      (genericOverlay self.inputs.nixpkgs)
      (
        final: prev:
        let
          marchFilter =
            version:
            # old version of nixpkgs does not recognize znver5, use znver4 instead
            lib.optionalAttrs (lib.versionOlder version "25.05") { znver5 = "znver4"; };
          source = {
            pkgs2305 = "nixpkgs-2305";
            pkgs2311 = "nixpkgs-2311";
            pkgs2411 = {
              source = "nixpkgs-2411";
              overlays = [
                (
                  final: prev:
                  lib.optionalAttrs (nixpkgsConfig.march != null) {
                    pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
                      (final: prev: {
                        sphinx = prev.sphinx.overridePythonAttrs (prev: {
                          disabledTests = prev.disabledTests or [ ] ++ [ "test_xml_warnings" ];
                        });
                      })
                    ];
                  }
                )
              ];
            };
          };
          packages =
            name:
            let
              flakeSource = self.inputs.${source.${name}.source or source.${name}};
            in
            import flakeSource {
              localSystem =
                if nixpkgsConfig.march == null then
                  { system = "${nixpkgsConfig.arch or "x86_64"}-linux"; }
                else
                  let
                    march = (marchFilter flakeSource.lib.version).${nixpkgsConfig.march} or nixpkgsConfig.march;
                  in
                  {
                    system = "${nixpkgsConfig.arch or "x86_64"}-linux";
                    gcc = {
                      arch = march;
                      tune = march;
                    };
                  };
              inherit config;
              overlays = (source.${name}.overlays or [ ]) ++ [
                cudaOverlay
                rocmOverlay
                (genericOverlay flakeSource)
              ];
            };
        in
        builtins.listToAttrs (
          builtins.map (name: {
            inherit name;
            value = packages name;
          }) (builtins.attrNames source)
        )
      )
    ];
    patch = [
      (final: prev: {
        telegram-desktop = prev.telegram-desktop.override {
          unwrapped = prev.telegram-desktop.unwrapped.overrideAttrs (prev: {
            patches = prev.patches or [ ] ++ [ ./telegram.patch ];
          });
        };
        libvirt = (prev.libvirt.override { iptables = final.nftables; }).overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./libvirt.patch ];
        });
        tailscale = prev.tailscale.override { iptables = final.nftables; };
        root = prev.root.overrideAttrs (prev: {
          cmakeFlags = prev.cmakeFlags ++ [ "-DCMAKE_CXX_STANDARD=23" ];
        });
        boost188 = prev.boost188.overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./boost188.patch ];
        });
        chromium = prev.chromium.override (prev: {
          commandLineArgs = prev.commandLineArgs or "" + " --disable-features=GlobalShortcutsPortal";
        });
        google-chrome = prev.google-chrome.override (prev: {
          commandLineArgs = prev.commandLineArgs or "" + " --disable-features=GlobalShortcutsPortal";
        });
        xray = prev.xray.overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./xray.patch ];
        });
        btop = prev.btop.overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./btop.patch ];
        });
        prrte = prev.prrte.overrideAttrs (prev: {
          configureFlags = prev.configureFlags or [ ] ++ [ "--with-lsf" ];
          buildInputs = prev.buildInputs or [ ] ++ [
            final.localPkgs.lsf
            final.libnsl
          ];
        });
        cpptrace = prev.cpptrace.overrideAttrs (prev: {
          doCheck = !final.stdenv.hostPlatform.isStatic;
        });
        range-v3 = prev.range-v3.overrideAttrs (prev: {
          doCheck = final.stdenv.hostPlatform.isLinux;
          cmakeFlags =
            prev.cmakeFlags or [ ]
            ++ final.lib.optionals (!final.stdenv.hostPlatform.isLinux) [ "-DRANGE_V3_TESTS=OFF" ];
        });
        magic-enum = prev.magic-enum.overrideAttrs (prev: {
          cmakeFlags =
            prev.cmakeFlags or [ ]
            ++ final.lib.optionals (!final.stdenv.hostPlatform.isLinux) [ "-DMAGIC_ENUM_OPT_BUILD_TESTS=OFF" ];
        });
        httplib = prev.httplib.overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./httplib.patch ];
        });
        libmaddy-markdown = prev.libmaddy-markdown.overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./maddy.patch ];
        });
        pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
          (final: prev: {
            # test failed after patch boost, not sure why
            # astropy = prev.astropy.overridePythonAttrs (prev:
            #   { disabledTests = prev.disabledTests or [] ++ [ "test_iers_b_out_of_range_handling" ]; });
            # test failed after update monty
            sumo = prev.sumo.overridePythonAttrs (prev: {
              disabledTestPaths = prev.disabledTestPaths or [ ] ++ [
                "tests/tests_io/test_questaal.py"
                "tests/tests_io/test_castep.py"
              ];
            });
          })
        ];
        # TODO: wating for pr to be rebased https://github.com/niri-wm/niri/pull/1856
        # niri = prev.niri.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./niri.patch ]; });
        # allow tbb to be built on static platforms
        onetbb =
          if !final.stdenv.hostPlatform.isStatic then
            prev.onetbb
          else
            prev.onetbb.overrideAttrs {
              doCheck = false;
              cmakeFlags = prev.cmakeFlags or [ ] ++ [
                "-DTBB_TEST=OFF"
                "-DTBBMALLOC_BUILD=OFF"
                "-DBUILD_SHARED_LIBS=OFF"
              ];
            }
            |> lib.addMetaAttrs { badPlatforms = [ ]; };
        cp2k = prev.cp2k.overrideAttrs (prev: {
          patches = prev.patches or [ ] ++ [ ./cp2k.patch ];
        });
      })
    ];
    marchFix = [
      # TODO: report to upstream
      (
        final: prev:
        lib.optionalAttrs (prev.stdenv.hostPlatform.avx512Support) {
          gsl = prev.gsl.overrideAttrs { doCheck = false; };
        }
      )
      # (final: prev: lib.optionalAttrs (prev.stdenv.hostPlatform.sse4_1Support)
      #   { frei0r = final.genericPkgs.frei0r; })
      # (final: prev: lib.optionalAttrs (nixpkgsConfig.march == "alderlake")
      #   { redis = prev.redis.overrideAttrs (prev: { doCheck = false; }); })
      # (final: prev: lib.optionalAttrs (nixpkgsConfig.march == "cascadelake")
      #   { postgresql_17 = prev.postgresql_17.override { jitSupport = false; }; })
      (
        final: prev:
        lib.optionalAttrs (nixpkgsConfig.march != null) {
          # https://github.com/NixOS/nixpkgs/pull/522648
          openldap = prev.openldap.overrideAttrs (prev: {
            preCheck = prev.preCheck + ''
              rm -f tests/scripts/test*-sync*
            '';
          });
          # TODO: patch upstream
          assimp = prev.assimp.overrideAttrs { doCheck = false; };
          # not sure why but test SEGFAULT
          c-blosc = prev.c-blosc.overrideAttrs { doCheck = false; };
          c-blosc2 = prev.c-blosc2.overrideAttrs { doCheck = false; };
          libtpms = prev.libtpms.overrideAttrs { env.NIX_CFLAGS_COMPILE = "-Wno-error=stringop-overflow"; };
          # do not install doc
          eigen_5 = prev.eigen_5.overrideAttrs {
            postInstall = "";
            outputs = [ "out" ];
          };
          #   xen = prev.xen.overrideAttrs (prev: { patches = prev.patches or [] ++ [ ./xen.patch ]; });
          lib2geom = prev.lib2geom.overrideAttrs (prev: {
            doCheck = false;
          });
          #   opencolorio = prev.opencolorio.overrideAttrs (prev: { doCheck = false; });
          rapidjson = prev.rapidjson.overrideAttrs { doCheck = false; };
          embree = prev.embree.override { stdenv = final.genericPkgs.stdenv; };
          simde = prev.simde.override { stdenv = final.genericPkgs.stdenv; };
          pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
            (final: prev: {
              picosvg = prev.picosvg.overridePythonAttrs { doCheck = false; };
              scipy = prev.scipy.overridePythonAttrs { doCheck = false; };
              # somehow run out of memory
              cryptography = prev.cryptography.overridePythonAttrs (prev: {
                disabledTestPaths = prev.disabledTestPaths or [ ] ++ [ "tests/hazmat/primitives/test_argon2.py" ];
              });
              # dscribe = prev.dscribe.overridePythonAttrs
              #   (prev: { disabledTests = prev.disabledTests or [] ++ [ "test_cell_list"  ]; });
            })
          ];
          libffi_3_3 = prev.libffi_3_3.overrideAttrs (prev: {
            doCheck = false;
          });
          perlPackages = prev.perlPackages.overrideScope (
            final: prev: {
              Test2Harness = prev.Test2Harness.overrideAttrs { doCheck = false; };
            }
          );
          gdal = prev.gdal.overrideAttrs (prev: {
            disabledTests = prev.disabledTests or [ ] ++ [ "test_transformer_tps_precision" ];
          });
        }
      )
    ];
    kernel310Fix = [
      (
        final: prev:
        lib.optionalAttrs (nixpkgsConfig.isKernel310 or false) {
          isKernel310 = true;
          linuxHeaders = prev.linuxHeaders.overrideAttrs (prev: {
            version = "3.10.108";
            src = final.fetchurl {
              url = "mirror://kernel/linux/kernel/v3.x/linux-3.10.108.tar.xz";
              hash = "sha256-OEnqgRlRf2BfnVPFfdbFOa+NWEwvHZAx9PVig680CaU=";
            };
            patches = prev.patches or [ ] ++ [ ./linux-310.patch ];
            buildPhase = ''
              make defconfig $makeFlags
              make headers_install $makeFlags
            '';
          });
          # ktls not working
          enableKTLS = false;
          gnutls = prev.gnutls.overrideAttrs (prev: {
            configureFlags = lib.remove "--enable-ktls" (prev.configureFlags or [ ]);
          });
          # x11 mostly not working
          gobjectSupport = false;
          withIntrospection = false;
          x11Support = false;
          enableGStreamer = false;
          # ftxui = prev.ftxui.overrideAttrs (prev: { nativeBuildInputs = [ final.cmake ]; });
          graphviz = null;
          vtk = null;
          # systemd does not working
          systemd = null;
          systemdMinimal = null;
          systemdLibs = null;
          udevCheckHook = null;
          bubblewrap = null;
          enableUdev = false;
          enableSystemd = false;
          withLogind = false;
          systemdSupport = false;
          udevSupport = false;
          withSystemd = false;
          # per package fixes
          audit = final.pkgs2411.audit;
          rpm =
            (prev.rpm.override {
              systemd = null;
              audit = null;
              libcap = null;
            }).overrideAttrs
              (prev: {
                cmakeFlags = prev.cmakeFlags or [ ] ++ [
                  "-DENABLE_TESTSUITE=OFF"
                  "-DWITH_CAP=OFF"
                  "-DWITH_AUDIT=OFF"
                  "-DWITH_ACL=OFF"
                ];
              });
          libsysprof-capture = prev.libsysprof-capture.overrideAttrs (prev: {
            patches = prev.patches or [ ] ++ [ ./sysprof.patch ];
          });
          gnupg = prev.gnupg.override { enableMinimal = true; };
          elfutils = prev.elfutils.overrideAttrs (prev: {
            env = prev.env or { } // {
              NIX_CFLAGS_COMPILE = "-Wno-error=unused-but-set-variable";
            };
          });
          go = prev.go.overrideAttrs { CGO_ENABLED = 0; };
          libfabric =
            (prev.libfabric.override {
              enablePsm2 = false;
              enableOpx = false;
            }).overrideAttrs
              (prev: {
                patches = prev.patches or [ ] ++ [ ./libfabric.patch ];
                # zero copy not working
                configureFlags = (prev.configureFlags or [ ]) ++ [ "--enable-tcp=no" ];
              });
          # fabric built but intel libpsm2 not
          # we using ucx anyway
          openmpi = prev.openmpi.override { fabricSupport = false; };
          libbpf = null;
          valgrind = null;
          valgrind-light = null;
          v4l-utils = prev.v4l-utils.overrideAttrs (prev: {
            mesonFlags = prev.mesonFlags or [ ] ++ [ (lib.mesonOption "bpf" "disabled") ];
          });
          # for ffmpeg
          withV4l2 = false;
          withVaapi = false;
          withDrm = false;
          withSdl2 = false;
          withHeadlessDeps = true;
          withSmallDeps = false;
          withFullDeps = false;
          # for openssh
          withFIDO = false;
          # for minio
          enableS3 = false;
          # bluez currently depend on systemd
          bluez = null;
          pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
            (final: prev: {
              tkinter = prev.tkinter.overridePythonAttrs { doCheck = false; };
              vtk = null;
              multidict = prev.multidict.overridePythonAttrs { doCheck = false; };
              django = prev.django.overridePythonAttrs { doCheck = false; };
              pillow-heif = prev.pillow-heif.overridePythonAttrs { doCheck = false; };
              pymatgen = prev.pymatgen.overridePythonAttrs { doCheck = false; };
            })
          ];
          folly = prev.folly.overrideAttrs (prev: {
            env = prev.env or { } // {
              NIX_CFLAGS_COMPILE = prev.env.NIX_CFLAGS_COMPILE or "" + " -DFOLLY_HAVE_SO_TIMESTAMPING=0";
            };
          });
          grpc = prev.grpc.overrideAttrs (prev: {
            buildInputs = prev.buildInputs or [ ] ++ [ final.linuxHeaders ];
          });
          fbthrift = null;
          procps = prev.procps.overrideAttrs (prev: {
            configureFlags = prev.configureFlags or [ ] ++ [ "--disable-pidwait" ];
            patches = prev.patches or [ ] ++ [ ./procps.patch ];
          });
          duc = prev.duc.override { enableCairo = false; };
          cp2k = (prev.cp2k.override { trexio = null; }).overrideAttrs (prev: {
            cmakeFlags = lib.filter (flag: !(lib.hasInfix "TREXIO" flag)) prev.cmakeFlags or [ ];
          });
        }
      )
    ];
  };
in
platformConfig
// {
  inherit config;
  overlays = builtins.concatLists (builtins.attrValues overlays);
}
