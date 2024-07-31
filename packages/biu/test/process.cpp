# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  auto result = biu::exec<{.SearchPath = true}>({.Program = "sleep", .Args = {"10"}, .Timeout = 3s});
  std::cout << "{}\n"_f(result.ExitCode);
  assert(!result);
}
