{ lib, pkgs, ... }:
let
  avdName = "tablet";
  owner = "avd";
  dataDir = "/var/lib/avd";
  avdHome = "${dataDir}/avd";

  systemImage = "system-images;android-36;google_apis;x86_64";

  # 1920x1080 平板：短边 1080 / (240 / 160) = 720dp，属于平板布局
  configOptions = {
    "hw.lcd.width" = "1920";
    "hw.lcd.height" = "1080";
    "hw.lcd.density" = "240";
    "hw.lcd.depth" = "24";
    "hw.initialOrientation" = "landscape";
    "hw.ramSize" = "4096";
    "hw.cpu.ncore" = "4";
    "hw.gpu.enabled" = "yes";
    "hw.gpu.mode" = "host";
    "hw.keyboard" = "yes";
    "hw.audioInput" = "no";
    "hw.audioOutput" = "no";
    "disk.dataPartition.size" = "256G";
    "skin.dynamic" = "yes";
  };

  sdk = (pkgs.androidenv.composeAndroidPackages {
    includeEmulator = true;
    includeSystemImages = true;
    includeCmake = false;
    toolsVersion = null;
    buildToolsVersions = [ ];
    platformVersions = [ "36" ];
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "x86_64" ];
  }).androidsdk;

  # androidsdk 只是 wrapper，真正的 SDK 根目录在 libexec 下
  androidSdkRoot = "${sdk}/libexec/android-sdk";
  adb = "${androidSdkRoot}/platform-tools/adb";
  emulator = "${androidSdkRoot}/emulator/emulator";

  # avdmanager 是 shell 脚本：它用 `which java` 探测 java，并用 awk 检查 JDK 版本，
  # 而 systemd 服务的最小 PATH（coreutils/findutils/gnugrep/gnused/systemd）
  # 里既没有 which 也没有 awk。java 本身不用管 —— nixpkgs 的 cmdline-tools
  # wrapper 已经把合适的 JDK 加进 PATH 了，自己再钉一个版本反而会在 nixpkgs
  # 更新 JDK 时对不上，所以只补 which / awk。
  toolPath = lib.makeBinPath [
    pkgs.which
    pkgs.gawk
  ];

  # systemd 服务不继承登录环境，这里手动准备 emulator 需要的一切
  environment = ''
    export HOME=${dataDir}
    export ANDROID_HOME=${androidSdkRoot}
    export ANDROID_SDK_ROOT=${androidSdkRoot}
    export ANDROID_USER_HOME=${dataDir}
    export ANDROID_AVD_HOME=${avdHome}
    export PATH=${toolPath}:${sdk}/bin:${androidSdkRoot}/platform-tools:$PATH
    # emulator 用 -gpu host 时会 dlopen libEGL / libvulkan
    export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  '';

  emulatorFlags = [
    "-avd"
    avdName
    "-port"
    "5554"
    "-no-window"
    "-no-boot-anim"
    "-no-snapshot"
    "-no-metrics"
    "-no-audio"
    "-gpu"
    "host"
    "-accel"
    "on"
    "-camera-back"
    "none"
    "-camera-front"
    "none"
    "-feature"
    "Vulkan"
  ];

  # 创建 AVD（如果还没有），并把 configOptions 里管理的项重写一遍，
  # 这样改这里的配置就能生效，而不需要手动改 config.ini。
  prepare = pkgs.writeShellScriptBin "avd-prepare" ''
    set -euo pipefail
    ${environment}

    mkdir -p "$ANDROID_AVD_HOME" "$HOME/.android"
    if [ ! -f "$HOME/.android/adbkey" ]; then
      ${adb} keygen "$HOME/.android/adbkey" >/dev/null
    fi

    if [ ! -f "$ANDROID_AVD_HOME/${avdName}.ini" ]; then
      echo no | ${sdk}/bin/avdmanager create avd \
        --force \
        --name ${avdName} \
        --package '${systemImage}' \
        --path "$ANDROID_AVD_HOME/${avdName}.avd"
    fi

    cfg="$ANDROID_AVD_HOME/${avdName}.avd/config.ini"
    touch "$cfg"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: _: ''sed -i '/^${key}=/d' "$cfg"'') configOptions
    )}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: value: ''echo '${key}=${value}' >> "$cfg"'') configOptions
    )}
  '';

  run = pkgs.writeShellScriptBin "avd-emulator" ''
    set -euo pipefail
    ${environment}
    exec ${emulator} ${lib.escapeShellArgs emulatorFlags} "$@"
  '';
in
{
  systemd = {
    tmpfiles.rules = [ "d ${dataDir} 0700 ${owner} ${owner} -" ];
    services = {
      avd-adb = {
        description = "Android Debug Bridge server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          User = owner;
          WorkingDirectory = dataDir;
          # 先准备好 adbkey，避免 adb server 和 emulator 各生成一个
          ExecStartPre = "${prepare}/bin/avd-prepare";
          ExecStart = "${adb} -a -P 5037 nodaemon server";
          Restart = "always";
          RestartSec = 5;
        };
      };
      avd = {
        description = "Android Virtual Device (${avdName})";
        wantedBy = [ "multi-user.target" ];
        after = [
          "avd-adb.service"
          "systemd-modules-load.service"
        ];
        wants = [ "avd-adb.service" ];
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          User = owner;
          WorkingDirectory = dataDir;
          ExecStartPre = "${prepare}/bin/avd-prepare";
          ExecStart = "${run}/bin/avd-emulator";
          Restart = "always";
          RestartSec = 15;
          # 留给 emulator 正常退出的时间
          TimeoutStopSec = 120;
          LimitNOFILE = 1048576;
        };
      };
    };
  };
  users = {
    users.${owner} = {
      isSystemUser = true;
      group = owner;
      extraGroups = [
        "kvm"
        "render"
      ];
    };
    groups.${owner} = { };
  };
}
