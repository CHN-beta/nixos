# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  for (auto [a, b] : biu::sequence(std::array{2, 2, 2}))
    std::cout << "{} {}\n"_f(a, b);
  std::optional<std::vector<int>> a;
  auto b = a.value_or(std::vector<int>{1, 2, 3})
    | biu::toLvalue
    | ranges::views::transform([](int i){ return i + 1; })
    | ranges::to_vector;
}
