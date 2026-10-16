{
  lib,
  pkgs,
  self,
  ...
}:
let
  # vLLM 0.16 requires Transformers < 5; Qwen's official ASR Space pins 4.57.6.
  # Keep the overrides private, including transitive Python dependencies.
  python = pkgs.python3.override (
    prev: {
      packageOverrides = lib.composeExtensions (prev.packageOverrides or (_: _: { })) (
        final: prev: {
          transformers = final.transformers_4;
          huggingface-hub = final.huggingface-hub_0;
          diffusers = prev.diffusers.overridePythonAttrs (old: {
            dependencies = (old.dependencies or [ ]) ++ [ final.httpx ];
          });
        }
      );
    }
  );
  package = python.pkgs.vllm.overridePythonAttrs (prev: {
    dependencies = (prev.dependencies or [ ]) ++ python.pkgs.vllm.optional-dependencies.audio;
  });
  model = self.src.models.qwen3-asr-1_7b;
in
{
  config = {
    environment.systemPackages = [ pkgs.voxtype ];
    programs.dms-shell.plugins.voxtype.enable = true;
    nixos.user.sharedModules = [
      {
        config = {
          services.voxtype = {
            enable = true;
            package = pkgs.voxtype;
            settings = {
              audio = {
                device = "default";
                feedback.enabled = true;
                max_duration_secs = 60;
                sample_rate = 16000;
              };
              engine = "whisper";
              hotkey.enabled = false;
              osd.enabled = false;
              output = {
                fallback_to_clipboard = true;
                mode = "clipboard";
                notification = {
                  on_recording_start = false;
                  on_recording_stop = false;
                  on_transcription = false;
                };
                type_delay_ms = 50;
              };
              state_file = "auto";
              whisper = {
                mode = "remote";
                remote_endpoint = "http://127.0.0.1:8000";
                model = "Qwen/Qwen3-ASR-1.7B";
                language = "zh";
              };
            };
          };
        };
      }
    ];
    users = {
      users.vllm = {
        isSystemUser = true;
        group = "vllm";
        extraGroups = [
          "render"
          "video"
        ];
        home = "/var/lib/vllm";
      };
      groups.vllm = { };
    };
    systemd.services.vllm = {
      description = "Qwen3-ASR speech recognition (vLLM / ROCm)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # PyTorch/Triton may invoke a compiler for JIT kernels.
      path = [ pkgs.python3Packages.torch.stdenv.cc ];
      environment = {
        HOME = "/var/lib/vllm";
        # /var/lib is persistent on pc; model weights are supplied by the Nix store.
        HF_HUB_OFFLINE = "1";
        TRANSFORMERS_OFFLINE = "1";
        XDG_CACHE_HOME = "/var/lib/vllm/.cache";
        HF_HUB_DISABLE_TELEMETRY = "1";
        ROCM_PATH = "${pkgs.rocmPackages.clr}";
        VLLM_NO_USAGE_STATS = "1";
      };
      serviceConfig = {
        Type = "simple";
        User = "vllm";
        Group = "vllm";
        StateDirectory = "vllm";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/vllm";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe' package "vllm")
          "serve"
          (toString model)
          "--served-model-name"
          "Qwen/Qwen3-ASR-1.7B"
          "--host"
          "127.0.0.1"
          "--port"
          "8000"
          "--max-num-seqs"
          "1"
          "--max-model-len"
          "4096"
          "--gpu-memory-utilization"
          "0.5"
          # Explicit 512 MiB KV cache; overrides percentage-based cache sizing.
          "--kv-cache-memory-bytes"
          "536870912"
        ];
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStopSec = 60;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        # Do not use PrivateDevices: ROCm needs /dev/kfd and /dev/dri.
        LimitMEMLOCK = "infinity";
      };
    };
  };
}
