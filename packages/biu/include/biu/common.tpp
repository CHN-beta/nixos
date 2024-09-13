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
  template <typename T> T& detail_::operator|(T&& obj, const ToLvalueHelper&) { return static_cast<T&>(obj); }
}
