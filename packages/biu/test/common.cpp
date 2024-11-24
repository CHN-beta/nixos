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
  
  struct test_struct
  {
    int a = 1;
    double b = 2;
    std::string c = "3";
  } c;
  biu::for_each([&](auto&& i){ std::cout << c.*i << '\n'; },
    std::tuple(&test_struct::a, &test_struct::b, &test_struct::c));
  struct test_struct2
  {
    int a = 4;
    double b = 5;
    std::string c = "6";
  } d;
  biu::for_each([&](auto&& i, auto&& j){ c.*i = d.*j; },
    std::tuple(&test_struct::a, &test_struct::b, &test_struct::c),
    std::tuple(&test_struct2::a, &test_struct2::b, &test_struct2::c));
}
