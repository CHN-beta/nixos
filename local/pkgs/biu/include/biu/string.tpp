# pragma once
# include <biu/string.hpp>

namespace biu
{
  namespace string
  {
    template <DecayedType Char, std::size_t N> constexpr
      BasicFixedString<Char, N>::BasicFixedString(const Char (&str)[N])
      { std::copy_n(str, N, Data); }
    template <DecayedType Char, std::size_t N> template <std::size_t M> requires (M<=N) constexpr
      BasicVariableString<Char, N>::BasicVariableString(const Char (&str)[M]) : Size(M)
    {
      std::fill(Data, Data + N, '\0');
      std::copy_n(str, M, Data);
    }
  }

  inline namespace stream_operators
  {
    template <typename Char, Char... c> inline std::basic_ostream<Char>& operator<<
      (std::basic_ostream<Char>& os, BasicStaticString<Char, c...>)
      { return os << std::basic_string_view{c...}; }
    template <typename Char, std::size_t N> std::basic_ostream<Char>& operator<<
      (std::basic_ostream<Char>& os, const BasicFixedString<Char, N>& str)
      { return os << std::basic_string_view<Char>(str.Data, str.Size); }
    template <typename Char, std::size_t N> std::basic_ostream<Char>& operator<<
      (std::basic_ostream<Char>& os, const BasicVariableString<Char, N>& str)
      { return os << std::basic_string_view<Char>(str.Data, str.Size); }
  }

  inline namespace literals
  {
    template <typename Char, Char... c> consteval BasicStaticString<Char, c...> operator""_ss()
      { return {}; }
    template <BasicFixedString FS> constexpr decltype(FS) operator""_fs()
      { return FS; }
  }
}
