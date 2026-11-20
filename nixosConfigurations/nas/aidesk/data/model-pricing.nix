# 计价基准：人民币元 / 百万 Token（CNY / 1M）。
# Gemini：直接采用官方 API 美元价格数字（1.0 × Base USD），
# 约为按汇率换算后的官方人民币价格的 1/7～1/6。
# DeepSeek：官方 API 峰时人民币价格 × 1.5，不区分峰谷。
# GPT：4router GptHyper（0.5 × Base USD）价格 × 2，即 1.0 × Base USD。
# Claude：4router ClaudeApiMix（1.8 × Base USD）价格 × 1.5，即 2.7 × Base USD。
# 豆包：火山方舟官方 API 人民币原价（1.0 × CNY）。
# intelligence：Artificial Analysis Intelligence Index（四舍五入为整数）。
# speed：Artificial Analysis Output Speed（tok/s，四舍五入为整数）。
# output-tokens-per-task：AA Intelligence Index v5.0.1 完整 9/9 基准实测的单任务加权平均输出 Token 数。
let
  geminiBetaTag = {
    color = "yellow";
    label = {
      "zh-CN" = "测试中";
      en = "Beta";
    };
    description = {
      "zh-CN" = "Google 新发布模型，上游渠道供应可能不稳定。";
      en = "Newly released Google model; upstream availability may be unstable.";
    };
  };
in
[
  # Gemini
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
    tags = [ geminiBetaTag ];
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
    model = "gemini-4-carbon";
    input = 2;
    cache-read = 0.1;
    output = 10;
    vendor = "google";
    intelligence = 60;
    speed = 51;
    output-tokens-per-task = 122768;
    zh-hint = "碳";
    tags = [ geminiBetaTag ];
  }
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
    tags = [ geminiBetaTag ];
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

  # Doubao
  {
    model = "doubao-seed-evolving";
    input = 6;
    cache-read = 1.2;
    output = 30;
    vendor = "bytedance";
  }

  # Claude
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

  # OpenAI
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
]
