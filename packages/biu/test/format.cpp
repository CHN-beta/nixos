# include <biu.hpp>

int main()
{
  using namespace biu::literals;

  std::optional<int> a = 3;
  using b = biu::detail_::UnderlyingTypeOfOptionalWrap<decltype(a)>::Type;
  std::cout << "{}\n"_f(nameof::nameof_full_type<b>());
  std::cout << "{}\n"_f(biu::concepts::CompletedType<fmt::formatter<int, char>>);
  std::cout << "{}\n"_f(biu::concepts::CompletedType<fmt::formatter<std::shared_ptr<int>, char>>);
  std::cout << "{}\n"_f(fmt::is_formattable<int>::value);
  std::cout << "{}\n"_f(a);
}
