{
	lib, stdenv, fetchurl, autoPatchelfHook,
	zlib, libffi, libffi_3_3, level-zero, ocl-icd, elfutils, numactl, libuuid, libxml2, sqlite, libpsm2, openssl_1_1,
	rdma-core, hwloc, ucx
}:
	
stdenv.mkDerivation rec
{
	version = "2023.2.1";
	pname = "oneapi";

	src =
		let
			# apt-cache depends --recurse intel-hpckit 2> /dev/null | grep -E "^intel-(hpckit|basekit|oneapi)" | sort | xargs apt download --print-uris 2> /dev/null | awk '{print $1}' | sed "s/'\(.*\)'/\1/" | sort
			debs =
			[
				"intel-oneapi-advisor-2023.2.0-49486_amd64.deb"
				"intel-oneapi-ccl-2021.10.0-2021.10.0-49084_amd64.deb"
				"intel-oneapi-ccl-devel-2021.10.0-2021.10.0-49084_amd64.deb"
				"intel-oneapi-ccl-devel-2021.10.0-49084_amd64.deb"
				"intel-oneapi-common-licensing-2023.2.0-2023.2.0-49462_all.deb"
				"intel-oneapi-common-licensing-2023.2.0-49462_all.deb"
				"intel-oneapi-common-vars-2023.2.0-49462_all.deb"
				"intel-oneapi-compiler-cpp-eclipse-cfg-2023.2.1-16_all.deb"
				"intel-oneapi-compiler-dpcpp-cpp-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-common-2023.2.1-2023.2.1-16_all.deb"
				"intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-runtime-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-classic-fortran-shared-runtime-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-common-2023.2.1-2023.2.1-16_all.deb"
				"intel-oneapi-compiler-dpcpp-cpp-runtime-2023.2.0-2023.2.0-49495_amd64.deb"
				"intel-oneapi-compiler-dpcpp-cpp-runtime-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-dpcpp-eclipse-cfg-2023.2.1-16_all.deb"
				"intel-oneapi-compiler-fortran-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-fortran-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-fortran-common-2023.2.1-2023.2.1-16_all.deb"
				"intel-oneapi-compiler-fortran-runtime-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-shared-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-compiler-shared-common-2023.2.1-2023.2.1-16_all.deb"
				"intel-oneapi-compiler-shared-runtime-2023.2.0-2023.2.0-49495_amd64.deb"
				"intel-oneapi-compiler-shared-runtime-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-condaindex-2023.2.0-49417_amd64.deb"
				"intel-oneapi-dal-2023.2.0-2023.2.0-49572_amd64.deb"
				"intel-oneapi-dal-common-2023.2.0-2023.2.0-49572_all.deb"
				"intel-oneapi-dal-common-devel-2023.2.0-2023.2.0-49572_all.deb"
				"intel-oneapi-dal-devel-2023.2.0-2023.2.0-49572_amd64.deb"
				"intel-oneapi-dal-devel-2023.2.0-49572_amd64.deb"
				"intel-oneapi-dev-utilities-2021.10.0-2021.10.0-49423_amd64.deb"
				"intel-oneapi-dev-utilities-2021.10.0-49423_amd64.deb"
				"intel-oneapi-dev-utilities-eclipse-cfg-2021.10.0-49423_all.deb"
				"intel-oneapi-diagnostics-utility-2022.4.0-49091_amd64.deb"
				"intel-oneapi-dnnl-2023.2.0-49516_amd64.deb"
				"intel-oneapi-dnnl-devel-2023.2.0-49516_amd64.deb"
				"intel-oneapi-dpcpp-cpp-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-dpcpp-ct-2023.2.0-2023.2.0-49330_amd64.deb"
				"intel-oneapi-dpcpp-ct-2023.2.0-49330_amd64.deb"
				"intel-oneapi-dpcpp-ct-eclipse-cfg-2023.2.0-49330_all.deb"
				"intel-oneapi-dpcpp-debugger-2023.2.0-2023.2.0-49330_amd64.deb"
				"intel-oneapi-dpcpp-debugger-2023.2.0-49330_amd64.deb"
				"intel-oneapi-icc-eclipse-plugin-cpp-2023.2.1-2023.2.1-16_all.deb"
				"intel-oneapi-inspector-2023.2.0-49301_amd64.deb"
				"intel-oneapi-ipp-2021.9.0-2021.9.0-49452_amd64.deb"
				"intel-oneapi-ipp-common-2021.9.0-2021.9.0-49452_all.deb"
				"intel-oneapi-ipp-common-devel-2021.9.0-2021.9.0-49452_all.deb"
				"intel-oneapi-ipp-devel-2021.9.0-2021.9.0-49452_amd64.deb"
				"intel-oneapi-ipp-devel-2021.9.0-49452_amd64.deb"
				"intel-oneapi-ippcp-2021.8.0-2021.8.0-49490_amd64.deb"
				"intel-oneapi-ippcp-common-2021.8.0-2021.8.0-49490_all.deb"
				"intel-oneapi-ippcp-common-devel-2021.8.0-2021.8.0-49490_all.deb"
				"intel-oneapi-ippcp-devel-2021.8.0-2021.8.0-49490_amd64.deb"
				"intel-oneapi-ippcp-devel-2021.8.0-49490_amd64.deb"
				"intel-oneapi-itac-2021.10.0-11_amd64.deb"
				"intel-oneapi-itac-2021.10.0-2021.10.0-11_amd64.deb"
				"intel-oneapi-libdpstd-devel-2022.2.0-2022.2.0-49284_amd64.deb"
				"intel-oneapi-libdpstd-devel-2022.2.0-49284_amd64.deb"
				"intel-oneapi-mkl-2023.2.0-2023.2.0-49495_amd64.deb"
				"intel-oneapi-mkl-common-2023.2.0-2023.2.0-49495_all.deb"
				"intel-oneapi-mkl-common-devel-2023.2.0-2023.2.0-49495_all.deb"
				"intel-oneapi-mkl-devel-2023.2.0-2023.2.0-49495_amd64.deb"
				"intel-oneapi-mkl-devel-2023.2.0-49495_amd64.deb"
				"intel-oneapi-mpi-2021.10.0-2021.10.0-49371_amd64.deb"
				"intel-oneapi-mpi-devel-2021.10.0-2021.10.0-49371_amd64.deb"
				"intel-oneapi-mpi-devel-2021.10.0-49371_amd64.deb"
				"intel-oneapi-openmp-2023.2.0-2023.2.0-49495_amd64.deb"
				"intel-oneapi-openmp-2023.2.1-2023.2.1-16_amd64.deb"
				"intel-oneapi-openmp-common-2023.2.0-2023.2.0-49495_all.deb"
				"intel-oneapi-openmp-common-2023.2.1-2023.2.1-16_all.deb"
				"intel-oneapi-tbb-2021.10.0-2021.10.0-49541_amd64.deb"
				"intel-oneapi-tbb-common-2021.10.0-2021.10.0-49541_all.deb"
				"intel-oneapi-tbb-common-devel-2021.10.0-2021.10.0-49541_all.deb"
				"intel-oneapi-tbb-devel-2021.10.0-2021.10.0-49541_amd64.deb"
				"intel-oneapi-tbb-devel-2021.10.0-49541_amd64.deb"
				"intel-oneapi-vtune-2023.2.0-49484_amd64.deb"
				"intel-oneapi-vtune-eclipse-plugin-vtune-2023.2.0-49484_all.deb"
			];
			hashes =
			[
				"1g5jda4zsmwavxn5mzn2k8fqbc9mj4swzjjn5728xx8d0d9l6m36"
				"0p32w5k1ymzydrldbfk6wchjkqs7j9hjpa5vvgra6ms1c3jcyj2s"
				"1knzb79qsp4xi9cs07g94gipaiqih442n0myz5nh60csl2lqh0q7"
				"02x17mwd8phimywq057cvb7hcnjqs5qxi3bif2sliymz4qawd4y9"
				"01q8k1h8qhqhh19mg04rd2bgskk8ka2jzbq0xq5bw18b9hlmbhff"
				"1p7padb8m9k9yyib2slhhgkavwp7g2wfsir3jk4bsdimgb53n9nv"
				"1kam3i1pfksf5srqrzislchhw51w76hgfb2qw2dibq97c592z25x"
				"0kxm1lv0jrdbk6gri6cq416a1arc8l71kp3cb8a39b70dzl9lx94"
				"0ah6p5zxb9msm3qs6xjnkqvjhjsab865yxbi6a4j9q9mhhbdmdkz"
				"13h4y701n6si0ixr8gx7rl4khmpgyayrwn2iwcp64qxhxh52ax5x"
				"019vanln5p471rmvsd2m253ivwvzcp1xfpr4l6p3j9csvcxilqz7"
				"0bl8rsxkzb7bwzy74amsj6183jnh1wc2dnkn99aq35dp30z74pqi"
				"11k074sy59amwldf9jmpsai3b030h5hb79r19l7sv43vb4v4332f"
				"1ahpwhnghdzkj8z8v31pqd2rlsmrgv3pfs85hqrw2pzm6nak94xm"
				"1ishj2dsbrpvl6x7nkmixxq7nqllc8y0myf2s2ls0h62lky0x6vz"
				"05ar5g5nazrxvbi4bgs5z50lhgvcwi63d7s2cwqz5g9c6lbk07cb"
				"01y4ax1hlcps50d9g4gmg9b8wgliyb9a6c3c8b9hppzk6gfl0bl8"
				"1i8balpd4aqw7w34siry7hk1ps46q3i2c7l626hg9yj7yyq4k7vc"
				"1cm02pggvhnsd044zj9rkm32jnblfw10cyzi45agi6c0vj5vbpp5"
				"0kqmhgm5mkqab2ljc20c880s9zragkn0zn02rqg2wip4nwl0lmiv"
				"1w7wxiydl62x8h5qw3n11niq295f1cwy1b86zg0vdzl51x04fggn"
				"0bwni8ypqnhbv7ld0adszc7x3lfkqnw57n1xjxc9qxc2i1h4s76r"
				"1z9l0rwbvfbizbj613s2gyik2zkfrps5j7d6kzrpxx1rrkvvr030"
				"07sfqv5b3c0y0sd7cfwl9ifwk1hx5kygv1c7fgrmqvkg6mwkjric"
				"1slwy1gabv1z2xlsn94lcz6h4xl7b3603xm4xpdmdw5dfq1l9b6y"
				"0shpk0mszkxg866ami19j9sbmj1z7gwpnsn0n6hbbzwlcql2k7ys"
				"1bb597hgqahh78m2k72z6k058hbfph2swnyqz2l14dpsn38sywmg"
				"0f8qr3mgrpw8899gh8fj03az4hj1rdmckgfji3n1h58jhan0dln9"
				"0cjmb271ip9jj8fxpif16yhk94ifljjiwlim8xgd6v5za30sd2n8"
				"1ay1dzad36sls75hglvgf46hakzphs5r02l2skhqijfss1d4pbbb"
				"0p899rqq6dzgi67qsiyvn664xqb14vksdn1j6i0xaa45rq40ls7i"
				"1q9kkd7s3w2cyhlzg2lzf8b4ragqp943j4mpwhfga8ayad6llfl3"
				"0nk0aijnhw25pdp8i7lfv1wg5gccqzyhbbzgq593mgpdj9z17yyw"
				"0gi35h76n9qpz5hr4wrlx9zb3a395qvgs3r3b12snb7sa417zkla"
				"0wnpb6yks4ibdl62awrkdxagzv2gj8y3ll0zkfxbx5azdk9cy040"
				"1jpc3cp04fscck1k77gf33dpalh51x29hri2pa8n4m7ig90lyzvx"
				"1pqbz5y56470pbcgvgnd5d7sg2bbiyj6w11w3h9287xysg36hc82"
				"0rb8fz3xmpyvcx4p0hd8xkbmwgqsfkqhiqlbh4wk98ar49izi8j9"
				"0mycpyqb2w8pah8zl2hh4m3d9ns292b22s24lp4ymnrj2m8r32hv"
				"1k9kdmw9z7jndglvrlk8jwbwvg1rg68scw1a9mk41sgzif5gcs63"
				"0lr85mmsm50zqjlxjcax9ps4lypbbjf5124s7d9pg452flzv693l"
				"0wa18ff0lvza4f1i0y8sbfq2fj3yj1mbbzm37dlpqp6zc40qniic"
				"1l78b1mfvglz89vik2fwpz097ymjwa4c3wnpmmfcwr5i2jh31x6x"
				"1rglrzgymbdvp01ngpm95z4wj9mq493bj4w2svsbyxgvg6mgw1q5"
				"0y18gxd5807flwm9hcqklmpfrri8w2b89qppml6yj0rh5gm4a4bh"
				"06ykgn5hgds2p9snz0pyf3pj4m0wlggzk6n0r8zmkjq0i4np3n0i"
				"1cz4d147wl0x1rf7d0087ah2ady75cr6b43al5cchwcii771b8q7"
				"1kfxsk026q0lqs12jim6h7f1xjrsygpal6xfhrais3n3ylbc23ph"
				"1kjjylfda84hiv7ckffs97kwmcg2jfb9sm16hrn3jlz15xfc0rsc"
				"01hz16hwrzmf30nbb3xk9kgfn915i0jwxx6244zhigfhcq82zkpp"
				"1h3y921yfy8azf64p8ip6lx4k01ja0j8rxbqsh413lclicm2q4f8"
				"1sy9chy77rzrggbvmpadd1spwli1s6rwpxh65panmh42qngmhi3j"
				"1vq1q39npmawy0aidrsvaslbdxb11a27dlmr6ba5rvl9r64gaf9d"
				"1r05b2k9573jiyj4vp1qp02dfghpshn9cpyzr4axnr9dxrzr4bjg"
				"0j09ms08rgdlws90530jc7bppx55rviy9kqdzqn3iiaijfhh755z"
				"1r19m24bxyvwznw1z15vr4g6r84cj4bhyln4pggipzhlkipf48k6"
				"14ba00zjlgjs16qsiwg7dmqcy47sfz741xndr7j21p10sw2zfbnv"
				"12wx24d0gw1m2p8kn1cc7mcsfmqg2mqqmw4ikgjxcza00ibny7an"
				"1vfxpa4bm1vkflin9hbh77qxhj0qz0k8sixwhpb97mahhz9fddz1"
				"0lkfagzsdfbd8fsvnlb568kc79c114fwmfg4fg77wk03dxlj7ykp"
				"1kiinh9kvw999k802cv664hkm960s2zc8v508665l79xy9d9s6ba"
				"07lsdiiq648zn0rvd7lfwsxwdh4m58gqx34dddmi5ggfb6c10px1"
				"1x338g3lfw8fqasa166hs7bhn9lrpnq61pyr2knlcqfal5g4jfg2"
				"1vfzw7ci99bwi017mwknfjcgcfs0qpw2yq02zx5wbrza81jlsz5a"
				"0y2g4lb0asq0snyj1as5c4hc2rf9dq9qlwcxkvai5rv37w3n5vx3"
				"0paj51gmn8i677ji0ggw2lkp85md7zm7kb944aprz31hm87scrbd"
				"163kry5mnfqgd85izcbjszhqdmp9v91d32gnj3i4f7v8ss5cn0h2"
				"08jw9dm9inms94290fi487zn2r237n537jklc7gbgkxg2yhj9s9x"
				"159sh6jq1q9mw6k950p1qrxnvppvmk6gcm9b0m6xd0pfpbmqp6ka"
				"1lmn6r9227k98g5hv7qbjlc902hcrmfykrxf3f3rydmgh2hdl4bc"
				"018lz0y4379rc5wyk3bnyyd4dhqkl0py6mrax73azf5nbynplndh"
				"1w86gwf3cwzp1fkhnrrcqnscbhhi4gair0v6il8j4327x91x3y4q"
				"0y4d6vf7nipsgymsqgz9w26dj9mja1il28dl5rxhzfcdd84ngzv3"
				"02vmpgsh5yghw8xsfha3cdxd99ymc3xmhq44336qgy6dq4khw0ah"
				"1a24gidhmcapp8b8n2r15bvklmarxgph3c87cb2hklbj7jqypvxb"
				"0jmxa197mny1dm6q45sb0p2plyiy0xvi328dwmy86l89wj5d9w21"
				"1gi023qyjrs88ilqccbg2bab8daaaxwywfsgrssmai8b8bj6vvdz"
				"1gyx5zcm00cq35gkhdr6ipanvrxkg08nhy23djpnxfz1014vg7qr"
				"1giy4j35hn06x96ypd5wp60a8bm1fsbi74pgd7c3rphcmq55kyrr"
				"1rm4wjrsd62vzlrdw536xv6xgi1flb8ijk55h1fzgc7ygiqpnwla"
				"1zqqkphaskmxqwwsbv0hq1k7763nfny0h5s9krbg35dxndq7sv8f"
				"055fdiyxyi70vwjicjd1ri6gas5y8zhl3zq5fgdnyq9xrr68adbc"
				"0dbgviq2d4jgbj4nfqv0dmc7j5i46g6ns54adzaqy635mqcnbq8j"
				"0rq3ish5k9p78zzj24gg2q0fl2kipyrh6nnxfrikpmh9qkfrvjv1"
			];
			disabledPackages = [ "advisor" "inspector" "itac" "vtune" ];
			packages =
				builtins.filter
					(package: ! builtins.any (disabledPackage: lib.hasInfix disabledPackage package.filename) disabledPackages)
					(builtins.genList
						(i: { filename = builtins.elemAt debs i; hash = builtins.elemAt hashes i; })
						(builtins.length debs));
		in
		builtins.map
			(package: fetchurl
				{
					url = "https://apt.repos.intel.com/oneapi/pool/main/${package.filename}";
					sha256 = package.hash;
				}
			)
			packages;

	nativeBuildInputs = [ autoPatchelfHook ];
	propagatedBuildInputs =
	[
		stdenv.cc.cc zlib libffi level-zero ocl-icd libffi_3_3 elfutils numactl libuuid.lib libxml2 sqlite libpsm2
		openssl_1_1 rdma-core hwloc.lib ucx
	];
	autoPatchelfIgnoreMissingDeps =
	[
		# gcc 4.8
		"libhwloc.so.5"
	];

	# propagatedBuildInputs =
	# [
	# 	glibc glib libnotify xdg-utils ncurses nss 
	# 	at-spi2-core libxcb libdrm gtk3 mesa qt515.full 
	# 	zlib freetype fontconfig xorg.xorgproto xorg.libX11 xorg.libXt
	# 	xorg.libXft xorg.libXext xorg.libSM xorg.libICE
	# ];

	# libPath = lib.makeLibraryPath
	# [
	# 	stdenv.cc.cc libX11 glib libnotify xdg-utils 
	# 	ncurses nss at-spi2-core libxcb libdrm gtk3 
	# 	mesa qt515.full zlib atk nspr dbus pango cairo 
	# 	gdk-pixbuf cups expat libxkbcommon alsaLib
	# 	at-spi2-atk xorg.libXcomposite xorg.libxshmfence 
	# 	xorg.libXdamage xorg.libXext xorg.libXfixes
	# 	xorg.libXrandr
	# ];

	unpackPhase = lib.concatStrings (builtins.map (item:
	''
		echo unpack $(basename ${item})
		ar x ${item}
		tar xf data.tar.xz
	'') src);
	installPhase =
	''
		runHook preInstall

		rm -r opt/intel/oneapi/compiler/${version}/linux/lib/oclfpga

		mkdir $out
		mv opt/intel/oneapi $out/opt

		runHook postInstall
	'';
}