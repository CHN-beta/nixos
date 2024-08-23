# include <biu.hpp>
int main()
{
  using namespace biu::literals;
  biu::Atomic<std::string> a("hello");
  a = "world";
  a.apply([](auto& value) { value += "!"; });
  auto b = a.get();
  auto lock = a.lock(nullptr, nullptr);
  *lock = "!";
}
