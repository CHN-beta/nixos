# include <biu.hpp>

int main()
{
  using namespace biu::literals;

  std::optional<int> a = 3;
  std::cout << "{}\n"_f(a);
}
