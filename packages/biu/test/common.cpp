# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  for (auto [a, b] : biu::sequence(std::array{2, 2, 2}))
    std::cout << "{} {}\n"_f(a, b);
}
