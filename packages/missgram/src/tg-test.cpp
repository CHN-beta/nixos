# include <missgram.hpp>

# ifndef MISSGRAM_CONFIG_FILE
#   define MISSGRAM_CONFIG_FILE "./config.yaml"
# endif

int main()
{
  using namespace biu::literals;
  using namespace missgram;
  biu::Logger::Guard log;

  config = YAML::LoadFile(MISSGRAM_CONFIG_FILE).as<Config>();
  // tg_send("aaaa", std::nullopt, {});
  // tg_send("aaaa", std::nullopt, {{"IMG20241013173523.jpg", "https://xn--s8w913fdga.chn.moe/files/3dd41113-4df5-4f34-a825-e4137d146172", "image/jpeg", false}});
  tg_send("aaaa", std::nullopt,
  {
    {"2026-01-07 22-02-22 1.png", "https://xn--s8w913fdga.chn.moe/files/a23d13ea-de37-4907-9d54-66417d7e0e36", "image/png", false}
  });
  // tg_send("aaaa", std::nullopt,
  // {
  //   {"IMG20241013173523.jpg", "https://xn--s8w913fdga.chn.moe/files/// 3dd41113-4df5-4f34-a825-e4137d146172", "image/jpeg", true},
  //   {"2026-01-07 22-02-22 1.png", "https://xn--s8w913fdga.chn.moe/files/// a23d13ea-de37-4907-9d54-66417d7e0e36", "image/png", false}
  // });
}
