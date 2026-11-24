# 计价基准：人民币元 / 百万 Token（CNY / 1M）。
# Gemini：直接采用官方 API 美元价格数字（1.0 × Base USD），
# 约为按汇率换算后的官方人民币价格的 1/7～1/6。
# DeepSeek：官方 API 峰时人民币价格 × 1.5，不区分峰谷。
# GPT：4router GptHyper（0.5 × Base USD）价格 × 2，即 1.0 × Base USD。
# Claude：4router ClaudeApiMix（1.8 × Base USD）价格 × 1.5，即 2.7 × Base USD。
# intelligence：Artificial Analysis Intelligence Index（四舍五入为整数）。
# speed：Artificial Analysis Output Speed（tok/s，四舍五入为整数）。
# output-tokens-per-task：AA Intelligence Index v5.0.1 完整 9/9 基准实测的单任务加权平均输出 Token 数。
# 同一厂商按发布时间从新到旧排列，供模型选择器使用。
# TokenPlus：国内模型广场当前展示的人民币报价（CNY / 1M，含公开折扣）× 1.5；不换汇。
# Qwen 的缓存命中价采用默认隐式缓存档；阶梯按输入 Token 数选择。
# OpenRouter：10 × Base USD / 1M，直接作为 CNY。
[
  # Gemini
  {
    model = "gemini-4-neon";
    input = 3;
    cache-read = 0.15;
    output = 15;
    vendor = "google";
    intelligence = 61;
    speed = 110;
    output-tokens-per-task = 141631;
    zh-hint = "氖";
  }
  {
    model = "gemini-4-hydrogen";
    input = 1.5;
    cache-read = 0.075;
    output = 7.5;
    vendor = "google";
    intelligence = 54;
    speed = 164;
    output-tokens-per-task = 154406;
    zh-hint = "氢";
    tags = [
      {
        color = "yellow";
        label = {
          "zh-CN" = "不稳定";
          en = "Unstable";
        };
        description = {
          "zh-CN" = "Google 上游服务目前存在异常，暂时无法解决，需等待 Google 官方修复。";
          en = "There is currently an issue on Google's side that cannot be resolved locally; awaiting a fix from Google.";
        };
      }
    ];
  }
  {
    model = "gemini-4-carbon";
    input = 2;
    cache-read = 0.1;
    output = 10;
    vendor = "google";
    intelligence = 60;
    speed = 51;
    output-tokens-per-task = 122768;
    zh-hint = "碳";
  }
  {
    model = "gemini-4-argon";
    input = 2;
    cache-read = 0.1;
    output = 10;
    vendor = "google";
    intelligence = 50;
    speed = 68;
    output-tokens-per-task = 116368;
    zh-hint = "氩";
  }
  {
    model = "gemini-3.8-flash";
    input = 0.75;
    cache-read = 0.075;
    output = 3.75;
    vendor = "google";
    intelligence = 31;
    speed = 116;
    output-tokens-per-task = 98940;
  }

  # DeepSeek
  {
    model = "deepseek-flash";
    input = 3;
    cache-read = 0.06;
    output = 12;
    vendor = "deepseek";
    intelligence = 33;
    speed = 163;
    output-tokens-per-task = 138962;
  }
  {
    model = "deepseek-v4-pro";
    input = 13.5;
    cache-read = 0.45;
    output = 40.5;
    vendor = "deepseek";
    intelligence = 23;
    speed = 78;
    output-tokens-per-task = 98733;
  }

  # OpenAI
  {
    model = "gpt-6.2-sol";
    input = 2;
    cache-read = 0.1;
    cache-write = 2.5;
    output = 10;
    vendor = "openai";
    intelligence = 57;
    speed = 72;
    output-tokens-per-task = 40360;
    zh-hint = "太阳";
  }
  {
    model = "gpt-6.2-astra";
    input = 8;
    cache-read = 0.4;
    cache-write = 10;
    output = 40;
    vendor = "openai";
    intelligence = 62;
    speed = 48;
    output-tokens-per-task = 41029;
    zh-hint = "星辰";
  }
  {
    model = "gpt-6.1-terra";
    input = 1;
    cache-read = 0.05;
    cache-write = 1.25;
    output = 5;
    vendor = "openai";
    intelligence = 51;
    speed = 62;
    output-tokens-per-task = 59883;
    zh-hint = "大地";
  }
  {
    model = "gpt-6.1-sol";
    input = 2;
    cache-read = 0.1;
    cache-write = 2.5;
    output = 10;
    vendor = "openai";
    intelligence = 55;
    speed = 46;
    output-tokens-per-task = 67824;
    zh-hint = "太阳";
  }
  {
    model = "gpt-6-luna";
    input = 0.1;
    cache-read = 0.01;
    cache-write = 0.125;
    output = 0.5;
    tiers = [
      {
        min-input-tokens = 272001;
        input = 0.2;
        cache-read = 0.02;
        cache-write = 0.25;
        output = 0.75;
      }
    ];
    vendor = "openai";
    intelligence = 28;
    speed = 100;
    output-tokens-per-task = 75296;
    zh-hint = "月神";
  }
  {
    model = "gpt-6-sol";
    input = 2;
    cache-read = 0.2;
    cache-write = 2.5;
    output = 10;
    tiers = [
      {
        min-input-tokens = 272001;
        input = 4;
        cache-read = 0.4;
        cache-write = 5;
        output = 15;
      }
    ];
    vendor = "openai";
    intelligence = 44;
    speed = 112;
    output-tokens-per-task = 53890;
    zh-hint = "太阳";
  }
  {
    model = "gpt-6-astra";
    input = 10;
    cache-read = 1;
    cache-write = 12.5;
    output = 50;
    vendor = "openai";
    intelligence = 57;
    speed = 41;
    output-tokens-per-task = 51973;
    zh-hint = "星辰";
  }
  {
    model = "gpt-5.6-luna";
    input = 0.2;
    cache-read = 0.02;
    cache-write = 0.25;
    output = 1.2;
    tiers = [
      {
        min-input-tokens = 272001;
        input = 0.4;
        cache-read = 0.04;
        cache-write = 0.5;
        output = 1.8;
      }
    ];
    vendor = "openai";
    intelligence = 24;
    speed = 98;
    output-tokens-per-task = 59003;
    zh-hint = "月神";
  }
  {
    model = "gpt-5.6-terra";
    input = 2;
    cache-read = 0.2;
    cache-write = 2.5;
    output = 12;
    tiers = [
      {
        min-input-tokens = 272001;
        input = 4;
        cache-read = 0.4;
        cache-write = 5;
        output = 18;
      }
    ];
    vendor = "openai";
    intelligence = 32;
    speed = 82;
    output-tokens-per-task = 66249;
    zh-hint = "大地";
  }
  {
    model = "gpt-5.6-sol";
    input = 4;
    cache-read = 0.4;
    cache-write = 5;
    output = 20;
    tiers = [
      {
        min-input-tokens = 272001;
        input = 8;
        cache-read = 0.8;
        cache-write = 10;
        output = 30;
      }
    ];
    vendor = "openai";
    intelligence = 61;
    speed = 95;
    zh-hint = "太阳";
  }

  # Claude
  {
    model = "claude-fable-5-2";
    input = 21.6;
    cache-read = 0.54;
    cache-write = 27;
    output = 108;
    vendor = "anthropic";
    intelligence = 65;
    speed = 110;
    output-tokens-per-task = 273776;
    zh-hint = "寓言";
  }
  {
    model = "claude-haiku-5-5";
    input = 0.27;
    cache-read = 0.027;
    cache-write = 0.3375;
    output = 1.35;
    tiers = [
      {
        min-input-tokens = 100001;
        input = 1.35;
        cache-read = 0.135;
        cache-write = 1.6875;
        output = 6.75;
      }
    ];
    vendor = "anthropic";
    intelligence = 36;
    speed = 252;
    output-tokens-per-task = 225966;
    zh-hint = "俳句";
  }
  {
    model = "claude-sonnet-5-5";
    input = 5.4;
    cache-read = 0.27;
    cache-write = 6.75;
    output = 27;
    vendor = "anthropic";
    intelligence = 55;
    speed = 144;
    output-tokens-per-task = 285387;
    zh-hint = "十四行诗";
  }
  {
    model = "claude-opus-5-5";
    input = 10.8;
    cache-read = 0.54;
    cache-write = 13.5;
    output = 54;
    vendor = "anthropic";
    intelligence = 59;
    speed = 112;
    output-tokens-per-task = 173313;
    zh-hint = "巨著";
  }
  {
    model = "claude-opus-5";
    input = 13.5;
    cache-read = 1.35;
    cache-write = 16.875;
    output = 67.5;
    vendor = "anthropic";
    intelligence = 44;
    speed = 80;
    output-tokens-per-task = 118068;
    zh-hint = "巨著";
  }
  {
    model = "claude-sonnet-5";
    input = 5.4;
    cache-read = 0.54;
    cache-write = 6.75;
    output = 27;
    vendor = "anthropic";
    intelligence = 55;
    speed = 103;
    zh-hint = "十四行诗";
  }
  {
    model = "claude-opus-4-8";
    input = 13.5;
    cache-read = 1.35;
    cache-write = 16.875;
    output = 67.5;
    vendor = "anthropic";
    intelligence = 57;
    speed = 84;
    zh-hint = "巨著";
  }
  {
    model = "claude-opus-4-7";
    input = 13.5;
    cache-read = 1.35;
    cache-write = 16.875;
    output = 67.5;
    vendor = "anthropic";
    intelligence = 55;
    speed = 83;
    zh-hint = "巨著";
  }
  {
    model = "claude-sonnet-4-6";
    input = 8.1;
    cache-read = 0.81;
    cache-write = 10.125;
    output = 40.5;
    vendor = "anthropic";
    intelligence = 37;
    speed = 59;
    zh-hint = "十四行诗";
  }
  {
    model = "claude-opus-4-6";
    input = 13.5;
    cache-read = 1.35;
    cache-write = 16.875;
    output = 67.5;
    vendor = "anthropic";
    intelligence = 39;
    speed = 52;
    zh-hint = "巨著";
  }
  {
    model = "claude-haiku-4-5";
    input = 2.7;
    cache-read = 0.27;
    cache-write = 3.375;
    output = 13.5;
    vendor = "anthropic";
    intelligence = 7;
    speed = 106;
    output-tokens-per-task = 25258;
    zh-hint = "俳句";
  }

  # Doubao
  {
    model = "doubao-seed-2-1-pro";
    vendor = "bytedance";
    input = 9;
    output = 45;
    cache-read = 1.8;
  }

  # zhipu
  {
    model = "glm-5.3";
    vendor = "zhipu";
    input = 4.8;
    output = 16.8;
    cache-read = 1.2;
    intelligence = 32;
    speed = 73;
    output-tokens-per-task = 118987;
  }
  {
    model = "glm-5.3-flash";
    vendor = "zhipu";
    input = 0.48;
    output = 1.68;
    cache-read = 0.138;
    intelligence = 28;
    speed = 56;
    output-tokens-per-task = 134205;
  }
  {
    model = "glm-5.2";
    vendor = "zhipu";
    input = 4.8;
    output = 16.8;
    cache-read = 1.2;
    speed = 59;
  }
  {
    model = "glm-5.1";
    vendor = "zhipu";
    input = 4.95;
    output = 19.8;
    cache-read = 1.0725;
    tiers = [
      {
        min-input-tokens = 32000;
        input = 6.6;
        output = 23.1;
        cache-read = 1.65;
      }
    ];
    speed = 79;
  }

  # alibaba
  {
    model = "qwen4-max";
    vendor = "alibaba";
    input = 7.05;
    output = 21.15;
    cache-read = 0.3525;
    intelligence = 43;
    speed = 60;
    output-tokens-per-task = 104940;
  }
  {
    model = "qwen3.8-max";
    vendor = "alibaba";
    input = 9.45;
    output = 28.35;
    cache-read = 1.18125;
    # AA：0902 快照。
    intelligence = 34;
    speed = 59;
    output-tokens-per-task = 170794;
  }
  {
    model = "qwen3.7-max";
    vendor = "alibaba";
    input = 6.75;
    output = 20.25;
    cache-read = 0.84375;
    speed = 143;
  }

  # moonshot
  {
    model = "kimi-k3.1-pro";
    vendor = "moonshot";
    input = 12.285;
    output = 64.26;
    cache-read = 1.2285;
    intelligence = 46;
    speed = 31;
    output-tokens-per-task = 72239;
  }
  {
    model = "kimi-k3";
    vendor = "moonshot";
    input = 15.75;
    output = 78.75;
    cache-read = 1.575;
    # AA 仅 Low 档有完整指数和 Token 数据。
    intelligence = 17;
    speed = 40;
    output-tokens-per-task = 39666;
  }
  {
    model = "kimi-k2.7-code";
    vendor = "moonshot";
    input = 4.875;
    output = 20.25;
    cache-read = 1.95;
    speed = 50;
  }

  # minimax
  {
    model = "minimax-m3.1-flash";
    vendor = "minimax";
    input = 1.5;
    output = 6;
    cache-read = 0.15;
    intelligence = 29;
    speed = 120;
    output-tokens-per-task = 138176;
  }
  {
    model = "minimax-m3";
    vendor = "minimax";
    input = 3.15;
    output = 12.6;
    cache-read = 0.63;
    intelligence = 19;
    speed = 79;
    output-tokens-per-task = 91452;
  }

  # Tencent
  {
    model = "hy4-flash";
    vendor = "tencent";
    input = 0.45;
    output = 1.8;
    cache-read = 0.018;
  }
  {
    model = "hy4";
    vendor = "tencent";
    input = 5.4;
    output = 16.2;
    cache-read = 0.27;
    intelligence = 35;
    speed = 92;
    output-tokens-per-task = 78058;
  }

  # xai
  {
    model = "grok-4.7";
    vendor = "xai";
    input = 20;
    output = 60;
    cache-read = 5;
    intelligence = 35;
    speed = 69;
    output-tokens-per-task = 104531;
  }
  {
    model = "grok-4.6";
    vendor = "xai";
    input = 20;
    output = 60;
    cache-read = 5;
    intelligence = 31;
    speed = 78;
    output-tokens-per-task = 58431;
  }
  {
    model = "grok-4.5";
    vendor = "xai";
    input = 20;
    output = 60;
    cache-read = 3;
    speed = 75;
  }
  {
    model = "grok-4.20";
    vendor = "xai";
    input = 12.5;
    output = 25;
    cache-read = 2;
    # AA：0309 v2 的 Reasoning 档；原始 0309 页面未提供速度。
    speed = 120;
  }

  # meta
  {
    model = "llama-4-maverick";
    vendor = "meta";
    input = 3.5;
    output = 10;
    cache-read = 1.7;
    speed = 150;
  }
  {
    model = "llama-4-scout";
    vendor = "meta";
    input = 1;
    output = 3;
    cache-read = 0;
    speed = 95;
  }

  # mistral
  {
    model = "mistral-large-4-0";
    vendor = "mistral";
    input = 7;
    output = 21;
    cache-read = 0.7;
    intelligence = 26;
    speed = 57;
    output-tokens-per-task = 81951;
  }
  {
    model = "mistral-large-2512";
    vendor = "mistral";
    input = 5;
    output = 15;
    cache-read = 0.5;
    # AA 将 2512 版本列为 Mistral Large 3。
    speed = 64;
  }
  {
    model = "codestral-2508";
    vendor = "mistral";
    input = 3;
    output = 9;
    cache-read = 0.3;
  }
]
