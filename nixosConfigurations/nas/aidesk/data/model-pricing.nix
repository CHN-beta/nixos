[
  ## Gemini
  {
    model = "gemini-3.8-flash";
    input = 2.25; # 0.3375
    cache-read = 0.225; # 0.03375
    output = 11.25; # 1.6875
  }
  {
    model = "gemini-4-argon";
    input = 6; # 0.9
    cache-read = 0.3; # 0.045
    output = 30; # 4.5
  }
  {
    model = "gemini-4-carbon";
    input = 6; # 0.9
    cache-read = 0.3; # 0.045
    output = 30; # 4.5
  }
  {
    model = "gemini-4-hydrogen";
    input = 4.5; # 0.675
    cache-read = 0.225; # 0.03375
    output = 22.5; # 3.375
  }
  ## DeepSeek
  {
    model = "deepseek-flash";
    input = 3;
    cache-read = 0.06;
    output = 12;
  }
  {
    model = "deepseek-v4-pro";
    input = 13.5;
    cache-read = 0.45;
    output = 40.5;
  }
  ## Doubao
  {
    model = "doubao-seed-evolving";
    input = 9;
    cache-read = 1.8;
    output = 45;
  }
  ## Claude
  {
    model = "claude-fable-5-2";
    input = 21.6;
    cache-read = 0.54;
    cache-write = 27;
    output = 108;
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
  }
  {
    model = "claude-sonnet-5-5";
    input = 5.4;
    cache-read = 0.27;
    cache-write = 6.75;
    output = 27;
  }
  {
    model = "claude-opus-5-5";
    input = 10.8;
    cache-read = 0.54;
    cache-write = 13.5;
    output = 54;
  }
  # OpenAI
  {
    model = "gpt-6.2-astra";
    input = 6;
    cache-read = 0.3;
    cache-write = 7.5;
    output = 30;
  }
  {
    model = "gpt-6.2-sol";
    input = 1.5;
    cache-read = 0.075;
    cache-write = 1.875;
    output = 7.5;
  }
]
