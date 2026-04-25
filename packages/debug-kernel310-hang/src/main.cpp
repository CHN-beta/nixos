# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  auto output = biu::exec<{.SearchPath = true, .Stdout = biu::IoType::String}>
    ({.Program="ssh-add", .Args={ "-l" }});
  std::cout << "{} {}\n"_f(output.ExitCode, output.Stdout);
}
