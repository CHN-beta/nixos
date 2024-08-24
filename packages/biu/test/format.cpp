# include <biu.hpp>

int main()
{
  using namespace biu::literals;

  std::optional<int> a = 3;
  std::cout << "{}\n"_f(a);

  auto b = "hello"s;
  auto c = "h(ell)o"_re;
  std::smatch d;
  assert(std::regex_match(b, d, c));
  assert("{}"_f(d[1]) == "ell");
}
