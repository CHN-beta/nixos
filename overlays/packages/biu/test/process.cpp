# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  biu::Logger::Guard log;
  auto result = biu::exec<{.SearchPath = true, .Timeout = true}>
    ({.Program = "sleep", .Args = {"10"}, .Timeout = 3s});
  std::cout << "{}\n"_f(result.ExitCode);
  assert(!result);
  auto result2 = biu::exec<{.SearchPath = true, .Stdout = biu::IoType::String}>
    ({.Program = "echo", .Args = {"hello world"}});
  std::cout << "{}\n"_f(result2.ExitCode);
  assert(result2);
}
