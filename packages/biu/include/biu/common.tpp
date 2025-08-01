# pragma once
# include <boost/functional/hash.hpp>
# include <zpp_bits.h>
# include <biu/common.hpp>

namespace biu::common
{
  void unused(auto&&...) {}
  std::size_t hash(auto&&... objs)
  {
    std::size_t result = 0;
    (boost::hash_combine(result, objs), ...);
    return result;
  }

  template <typename String> constexpr bool CaseInsensitiveStringLessComparator::operator()
    (const String& s1, const String& s2) const
  {
    return std::lexicographical_compare
    (
      s1.begin(), s1.end(), s2.begin(), s2.end(),
      [](char c1, char c2){return std::tolower(c1) < std::tolower(c2);}
    );
  }

  template <typename Array> concurrencpp::generator<std::pair<Array, std::size_t>> sequence(Array from, Array to)
  {
# ifndef NDEBUG
    assert(from.size() == to.size());
    for (std::size_t i = 0; i < from.size(); i++) assert(from[i] < to[i]);
# endif
    Array current = from;
    std::size_t total = 0;
    auto make_next = [&](this auto&& self, std::size_t i)
    {
      if (i == from.size()) return false;
      else if (current[i] + 1 == to[i]) { current[i] = from[i]; return self(i + 1); }
      else { current[i]++; total++; return true; }
    };
    do { co_yield {current, total}; } while (make_next(0));
  }
  template <typename Array> concurrencpp::generator<std::pair<Array, std::size_t>> sequence(Array to)
  {
    auto from = to;
    for (std::size_t i = 0; i < from.size(); i++) from[i] = 0;
    return sequence(from, to);
  }
  template <typename Byte> detail_::ReadReturnType<Byte>::Type read(std::istream&& input)
    { return read<Byte>(input); }
  template <typename T> T& detail_::operator|(T&& obj, const ToLvalueHelper&) { return static_cast<T&>(obj); }

  template <typename Function, typename T, typename... Ts> void for_each(Function&& function, T&& arg, Ts&&... args)
  {
    if constexpr (sizeof...(Ts) == 0)
    {
      [&]<std::size_t... Is>(std::index_sequence<Is...>)
        { (std::forward<Function>(function)(std::get<Is>(std::forward<T>(arg))) , ...); }
        (std::make_index_sequence<sizeof...(Ts)>{});
    }
    else
    {
      [&]<typename Tuple, std::size_t... Is>(std::index_sequence<Is...>, Tuple&& tuple)
      {
        ([&]<std::size_t I, std::size_t... Js>(std::index_sequence<Js...>) -> decltype(auto)
        {
          std::apply
          (
            std::forward<Function>(function),
            std::forward_as_tuple(std::get<I>(std::get<Js>(std::forward<Tuple>(tuple)))...));
        }.template operator()<Is>(std::make_index_sequence<std::tuple_size_v<Tuple>>{}), ...);
      }
      (
        std::make_index_sequence<std::tuple_size_v<T>>{},
        std::forward_as_tuple(std::forward<T>(arg), std::forward<Ts>(args)...)
      );
    }
  }

  template <typename T> decltype(auto) perfect_return(T&& obj)
  {
    // 不允许返回右值引用
    static_assert(!std::is_rvalue_reference_v<T>);
    // 左值引用则返回左值引用
    if constexpr (std::is_lvalue_reference_v<T>) return (obj);
    // 否则，假定可以移动，并返回值
    else
    {
      static_assert(std::is_move_constructible_v<std::remove_reference_t<T>>);
      return std::move(obj);
    }
  }
}
