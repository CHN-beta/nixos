# include <biu.hpp>
int main()
{
  using namespace biu::literals;
  biu::Atomic<std::string> a("hello");
  a = "world";
  a.apply([](auto& value) { value += "!"; });
  auto b = a.get();
  auto lock = a.lock();
  *lock = "!";
  static_assert(std::same_as<decltype(a.apply([](auto& value) { value += "!"; })), biu::Atomic<std::string>&>);
  static_assert(std::same_as<decltype(a.apply([](auto&) { return 3; })), int>);
  static_assert(std::same_as<decltype(a.apply([](auto&) {}, [](auto&){ return true; }, 1s)), bool>);
  static_assert
    (std::same_as<decltype(a.apply([](auto&) { return 3; }, [](auto&){ return true; }, 1s)), std::optional<int>>);
}
