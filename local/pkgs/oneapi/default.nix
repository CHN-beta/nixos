{
	lib, stdenv, fetchurl, autoPatchelfHook, strace,
	alsa-lib, at-spi2-atk, bzip2, cairo, numactl, pango, glib, gdk-pixbuf, xorg, libjpeg, gtk3, libkrb5, ncurses5, kmod,
	rdma-core, gtk2, nss, libxcrypt-legacy, gdbm, level-zero, hwloc, ucx, tcl, libffi_3_3, postgresql, libpng12, libpsm2,
	libndctl
}:
	
stdenv.mkDerivation rec
{
	version = "2023.1";
	pname = "oneapi";

	src = builtins.map
		(item: fetchurl
			{
				url = "https://apt.repos.intel.com/oneapi/pool/main/intel-${builtins.elemAt item 1}.deb";
				sha256 = builtins.elemAt item 0;
			}
		)
		[
			[ "1g5jda4zsmwavxn5mzn2k8fqbc9mj4swzjjn5728xx8d0d9l6m36" "basekit-2023.2.0-49384_amd64" ]
			[ "0p32w5k1ymzydrldbfk6wchjkqs7j9hjpa5vvgra6ms1c3jcyj2s" "basekit-getting-started-2023.2.0-49384_all" ]
			[ "1knzb79qsp4xi9cs07g94gipaiqih442n0myz5nh60csl2lqh0q7" "hpckit-2023.2.0-49438_amd64" ]
			[ "02x17mwd8phimywq057cvb7hcnjqs5qxi3bif2sliymz4qawd4y9" "hpckit-getting-started-2023.2.0-49438_all" ]
			[ "01q8k1h8qhqhh19mg04rd2bgskk8ka2jzbq0xq5bw18b9hlmbhff" "oneapi-advisor-2023.2.0-49486_amd64" ]
			[ "1p7padb8m9k9yyib2slhhgkavwp7g2wfsir3jk4bsdimgb53n9nv" "oneapi-ccl-2021.10.0-2021.10.0-49084_amd64" ]
			[ "1kam3i1pfksf5srqrzislchhw51w76hgfb2qw2dibq97c592z25x" "oneapi-ccl-devel-2021.10.0-2021.10.0-49084_amd64" ]
			[ "0kxm1lv0jrdbk6gri6cq416a1arc8l71kp3cb8a39b70dzl9lx94" "oneapi-ccl-devel-2021.10.0-49084_amd64" ]
			[ "0ah6p5zxb9msm3qs6xjnkqvjhjsab865yxbi6a4j9q9mhhbdmdkz" "oneapi-common-licensing-2023.2.0-2023.2.0-49462_all" ]
			[ "13h4y701n6si0ixr8gx7rl4khmpgyayrwn2iwcp64qxhxh52ax5x" "oneapi-common-licensing-2023.2.0-49462_all" ]
			[ "019vanln5p471rmvsd2m253ivwvzcp1xfpr4l6p3j9csvcxilqz7" "oneapi-common-vars-2023.2.0-49462_all" ]
			[ "0rdhilj794d3qa49my2phsl2qkyj1pb08q7hl5x532yk0k6xc32i" "oneapi-compiler-cpp-eclipse-cfg-2023.2.0-49495_all" ]
			[ "1qd6qf2rkh3wc7ly22nn4n89ahyw2n5a8l0y5cz4lfvdlzqbzjac"
				"oneapi-compiler-dpcpp-cpp-2023.2.0-2023.2.0-49495_amd64" ]
			[ "1vma2ddsa4ym8z086fr4fwcai8ip65q0kqr1aq8icjn8c0fbpav2" "oneapi-compiler-dpcpp-cpp-2023.2.0-49495_amd64" ]
			[ "1yp5bf3l0h9vy59rjvvv8k6p6pvyln62nvhpk2z50f1y1jrzxc6s"
				"oneapi-compiler-dpcpp-cpp-and-cpp-classic-2023.2.0-2023.2.0-49495_amd64" ]
			[ "0zidc5w3vbibqihimggm45zamdzzsq0b7xx2i835bwfm73m29cdc"
				"oneapi-compiler-dpcpp-cpp-and-cpp-classic-2023.2.0-49495_amd64" ]
			[ "10nr6l4m91jb209j3455an7f326r7dnbk2mmb71bz31f70fb8gw7"
				"oneapi-compiler-dpcpp-cpp-and-cpp-classic-common-2023.2.0-2023.2.0-49495_all" ]
			[ "1ymfr611k4ljcy150f5zjgbj58r6cmsf2fl7c2wcsgkgxafp63vq"
				"oneapi-compiler-dpcpp-cpp-and-cpp-classic-runtime-2023.2.0-2023.2.0-49495_amd64" ]
			[ "1y1x14kw4mla9vajhnlckk5r38wn2w2hbyjlgzq8wf7pwwciq71v"
				"oneapi-compiler-dpcpp-cpp-classic-fortran-shared-runtime-2023.2.0-2023.2.0-49495_amd64" ]
			[ "0c543crkx0zaqldpdgc8psq0fbgjdw28n9a9hyjicg2by81b5lr1"
				"oneapi-compiler-dpcpp-cpp-common-2023.2.0-2023.2.0-49495_all" ]
			[ "1w7wxiydl62x8h5qw3n11niq295f1cwy1b86zg0vdzl51x04fggn"
				"oneapi-compiler-dpcpp-cpp-runtime-2023.2.0-2023.2.0-49495_amd64" ]
			[ "1s7a042nm24d94lmfxr2rv5pkw02806ca6cwx8i57brrlhvafxgj" "oneapi-compiler-dpcpp-eclipse-cfg-2023.2.0-49495_all" ]
			[ "09j8s09rklrz6aiwm4cynw6czwmnnank61y4r3ywq2akk3n7fx2q" "oneapi-compiler-fortran-2023.2.0-2023.2.0-49495_amd64" ]
			[ "0vmsnpraw1js6ir8dyaq433xahpkwmprsh01i7jc8rjx27sp2v87" "oneapi-compiler-fortran-2023.2.0-49495_amd64" ]
			[ "0xbzz64wrzfq8hcrdysq12fl7s7w4c7dzgg082mni7pbxv442gwx" "oneapi-compiler-fortran-common-2023.2.0-2023.2.0-49495_all" ]
			[ "19zglniblb565j45a41kq0jn9ffb0i7w6w2i0wmp2xbs5c3clk40" "oneapi-compiler-fortran-runtime-2023.2.0-2023.2.0-49495_amd64" ]
			[ "0021pcjxkvcd04hmh1hw19rv8lal37vfi41swln0925wkqqh1dmz" "oneapi-compiler-shared-2023.2.0-2023.2.0-49495_amd64" ]
			[ "1abspspmr5r931ra0jaf5za52y1af1fnvx21lcacyjb4c0pjv16k" "oneapi-compiler-shared-common-2023.2.0-2023.2.0-49495_all" ]
			[ "1ay1dzad36sls75hglvgf46hakzphs5r02l2skhqijfss1d4pbbb" "oneapi-compiler-shared-runtime-2023.2.0-2023.2.0-49495_amd64" ]
			[ "1q9kkd7s3w2cyhlzg2lzf8b4ragqp943j4mpwhfga8ayad6llfl3" "oneapi-condaindex-2023.2.0-49417_amd64" ]
			[ "0nk0aijnhw25pdp8i7lfv1wg5gccqzyhbbzgq593mgpdj9z17yyw" "oneapi-dal-2023.2.0-2023.2.0-49572_amd64" ]
			[ "0gi35h76n9qpz5hr4wrlx9zb3a395qvgs3r3b12snb7sa417zkla" "oneapi-dal-common-2023.2.0-2023.2.0-49572_all" ]
			[ "0wnpb6yks4ibdl62awrkdxagzv2gj8y3ll0zkfxbx5azdk9cy040" "oneapi-dal-common-devel-2023.2.0-2023.2.0-49572_all" ]
			[ "1jpc3cp04fscck1k77gf33dpalh51x29hri2pa8n4m7ig90lyzvx" "oneapi-dal-devel-2023.2.0-2023.2.0-49572_amd64" ]
			[ "1pqbz5y56470pbcgvgnd5d7sg2bbiyj6w11w3h9287xysg36hc82" "oneapi-dal-devel-2023.2.0-49572_amd64" ]
			[ "0rb8fz3xmpyvcx4p0hd8xkbmwgqsfkqhiqlbh4wk98ar49izi8j9" "oneapi-dev-utilities-2021.10.0-2021.10.0-49423_amd64" ]
			[ "0mycpyqb2w8pah8zl2hh4m3d9ns292b22s24lp4ymnrj2m8r32hv" "oneapi-dev-utilities-2021.10.0-49423_amd64" ]
			[ "1k9kdmw9z7jndglvrlk8jwbwvg1rg68scw1a9mk41sgzif5gcs63" "oneapi-dev-utilities-eclipse-cfg-2021.10.0-49423_all" ]
			[ "0lr85mmsm50zqjlxjcax9ps4lypbbjf5124s7d9pg452flzv693l" "oneapi-diagnostics-utility-2022.4.0-49091_amd64" ]
			[ "0wa18ff0lvza4f1i0y8sbfq2fj3yj1mbbzm37dlpqp6zc40qniic" "oneapi-dnnl-2023.2.0-49516_amd64" ]
			[ "1l78b1mfvglz89vik2fwpz097ymjwa4c3wnpmmfcwr5i2jh31x6x" "oneapi-dnnl-devel-2023.2.0-49516_amd64" ]
			[ "0ppwbrf72li7q7ak5q4is53vmlc391xw9gbdig9viwp6l2qil1p9" "oneapi-dpcpp-cpp-2023.2.0-2023.2.0-49495_amd64" ]
			[ "0y18gxd5807flwm9hcqklmpfrri8w2b89qppml6yj0rh5gm4a4bh" "oneapi-dpcpp-ct-2023.2.0-2023.2.0-49330_amd64" ]
			[ "06ykgn5hgds2p9snz0pyf3pj4m0wlggzk6n0r8zmkjq0i4np3n0i" "oneapi-dpcpp-ct-2023.2.0-49330_amd64" ]
			[ "1cz4d147wl0x1rf7d0087ah2ady75cr6b43al5cchwcii771b8q7" "oneapi-dpcpp-ct-eclipse-cfg-2023.2.0-49330_all" ]
			[ "1kfxsk026q0lqs12jim6h7f1xjrsygpal6xfhrais3n3ylbc23ph" "oneapi-dpcpp-debugger-2023.2.0-2023.2.0-49330_amd64" ]
			[ "1kjjylfda84hiv7ckffs97kwmcg2jfb9sm16hrn3jlz15xfc0rsc" "oneapi-dpcpp-debugger-2023.2.0-49330_amd64" ]
			[ "1pf8q64qvn0s2w45vz3p4afs98xg56zl5075n54dlbagv064yipb" "oneapi-icc-eclipse-plugin-cpp-2023.2.0-2023.2.0-49495_all" ]
			[ "1h3y921yfy8azf64p8ip6lx4k01ja0j8rxbqsh413lclicm2q4f8" "oneapi-inspector-2023.2.0-49301_amd64" ]
			[ "1sy9chy77rzrggbvmpadd1spwli1s6rwpxh65panmh42qngmhi3j" "oneapi-ipp-2021.9.0-2021.9.0-49452_amd64" ]
			[ "1vq1q39npmawy0aidrsvaslbdxb11a27dlmr6ba5rvl9r64gaf9d" "oneapi-ipp-common-2021.9.0-2021.9.0-49452_all" ]
			[ "1r05b2k9573jiyj4vp1qp02dfghpshn9cpyzr4axnr9dxrzr4bjg" "oneapi-ipp-common-devel-2021.9.0-2021.9.0-49452_all" ]
			[ "0j09ms08rgdlws90530jc7bppx55rviy9kqdzqn3iiaijfhh755z" "oneapi-ipp-devel-2021.9.0-2021.9.0-49452_amd64" ]
			[ "1r19m24bxyvwznw1z15vr4g6r84cj4bhyln4pggipzhlkipf48k6" "oneapi-ipp-devel-2021.9.0-49452_amd64" ]
			[ "14ba00zjlgjs16qsiwg7dmqcy47sfz741xndr7j21p10sw2zfbnv" "oneapi-ippcp-2021.8.0-2021.8.0-49490_amd64" ]
			[ "12wx24d0gw1m2p8kn1cc7mcsfmqg2mqqmw4ikgjxcza00ibny7an" "oneapi-ippcp-common-2021.8.0-2021.8.0-49490_all" ]
			[ "1vfxpa4bm1vkflin9hbh77qxhj0qz0k8sixwhpb97mahhz9fddz1" "oneapi-ippcp-common-devel-2021.8.0-2021.8.0-49490_all" ]
			[ "0lkfagzsdfbd8fsvnlb568kc79c114fwmfg4fg77wk03dxlj7ykp" "oneapi-ippcp-devel-2021.8.0-2021.8.0-49490_amd64" ]
			[ "1kiinh9kvw999k802cv664hkm960s2zc8v508665l79xy9d9s6ba" "oneapi-ippcp-devel-2021.8.0-49490_amd64" ]
			[ "07lsdiiq648zn0rvd7lfwsxwdh4m58gqx34dddmi5ggfb6c10px1" "oneapi-itac-2021.10.0-11_amd64" ]
			[ "1x338g3lfw8fqasa166hs7bhn9lrpnq61pyr2knlcqfal5g4jfg2" "oneapi-itac-2021.10.0-2021.10.0-11_amd64" ]
			[ "1vfzw7ci99bwi017mwknfjcgcfs0qpw2yq02zx5wbrza81jlsz5a" "oneapi-libdpstd-devel-2022.2.0-2022.2.0-49284_amd64" ]
			[ "0y2g4lb0asq0snyj1as5c4hc2rf9dq9qlwcxkvai5rv37w3n5vx3" "oneapi-libdpstd-devel-2022.2.0-49284_amd64" ]
			[ "0paj51gmn8i677ji0ggw2lkp85md7zm7kb944aprz31hm87scrbd" "oneapi-mkl-2023.2.0-2023.2.0-49495_amd64" ]
			[ "163kry5mnfqgd85izcbjszhqdmp9v91d32gnj3i4f7v8ss5cn0h2" "oneapi-mkl-common-2023.2.0-2023.2.0-49495_all" ]
			[ "08jw9dm9inms94290fi487zn2r237n537jklc7gbgkxg2yhj9s9x" "oneapi-mkl-common-devel-2023.2.0-2023.2.0-49495_all" ]
			[ "159sh6jq1q9mw6k950p1qrxnvppvmk6gcm9b0m6xd0pfpbmqp6ka" "oneapi-mkl-devel-2023.2.0-2023.2.0-49495_amd64" ]
			[ "1lmn6r9227k98g5hv7qbjlc902hcrmfykrxf3f3rydmgh2hdl4bc" "oneapi-mkl-devel-2023.2.0-49495_amd64" ]
			[ "018lz0y4379rc5wyk3bnyyd4dhqkl0py6mrax73azf5nbynplndh" "oneapi-mpi-2021.10.0-2021.10.0-49371_amd64" ]
			[ "1w86gwf3cwzp1fkhnrrcqnscbhhi4gair0v6il8j4327x91x3y4q" "oneapi-mpi-devel-2021.10.0-2021.10.0-49371_amd64" ]
			[ "0y4d6vf7nipsgymsqgz9w26dj9mja1il28dl5rxhzfcdd84ngzv3" "oneapi-mpi-devel-2021.10.0-49371_amd64" ]
			[ "02vmpgsh5yghw8xsfha3cdxd99ymc3xmhq44336qgy6dq4khw0ah" "oneapi-openmp-2023.2.0-2023.2.0-49495_amd64" ]
			[ "0jmxa197mny1dm6q45sb0p2plyiy0xvi328dwmy86l89wj5d9w21" "oneapi-openmp-common-2023.2.0-2023.2.0-49495_all" ]
			[ "1gyx5zcm00cq35gkhdr6ipanvrxkg08nhy23djpnxfz1014vg7qr" "oneapi-tbb-2021.10.0-2021.10.0-49541_amd64" ]
			[ "1giy4j35hn06x96ypd5wp60a8bm1fsbi74pgd7c3rphcmq55kyrr" "oneapi-tbb-common-2021.10.0-2021.10.0-49541_all" ]
			[ "1rm4wjrsd62vzlrdw536xv6xgi1flb8ijk55h1fzgc7ygiqpnwla" "oneapi-tbb-common-devel-2021.10.0-2021.10.0-49541_all" ]
			[ "1zqqkphaskmxqwwsbv0hq1k7763nfny0h5s9krbg35dxndq7sv8f" "oneapi-tbb-devel-2021.10.0-2021.10.0-49541_amd64" ]
			[ "055fdiyxyi70vwjicjd1ri6gas5y8zhl3zq5fgdnyq9xrr68adbc" "oneapi-tbb-devel-2021.10.0-49541_amd64" ]
			[ "0dbgviq2d4jgbj4nfqv0dmc7j5i46g6ns54adzaqy635mqcnbq8j" "oneapi-vtune-2023.2.0-49484_amd64" ]
			[ "0rq3ish5k9p78zzj24gg2q0fl2kipyrh6nnxfrikpmh9qkfrvjv1" "oneapi-vtune-eclipse-plugin-vtune-2023.2.0-49484_all" ]
		];

	nativeBuildInputs = [ autoPatchelfHook ];
	propagatedBuildInputs =
	[
		alsa-lib at-spi2-atk bzip2 cairo numactl pango glib stdenv.cc.cc gdk-pixbuf xorg.xcbutilimage xorg.xcbutilkeysyms
		xorg.libICE libjpeg gtk3 xorg.xcbutilwm libkrb5 ncurses5 kmod.lib rdma-core xorg.xcbutilrenderutil gtk2 nss
		libxcrypt-legacy gdbm level-zero hwloc ucx tcl libffi_3_3 postgresql.lib libpng12 libndctl libpsm2
	];
	autoPatchelfIgnoreMissingDeps =
	[
		"libffi.so.6" "libgdbm.so.2" "libgdbm.so.4" "libsycl.so.5" "libopae-c.so.1" "libdb-4.7.so" "libssl.so.10"
		"libcrypto.so.10" "libmysqlclient.so.16" "libsafec-3.3.so.3"
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

		mkdir $out
		mv opt/intel/oneapi $out/opt

		runHook postInstall
	'';
}