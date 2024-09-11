# pragma once
# include <variant>
# include <optional>
# include <experimental/memory>
# include <biu/string.hpp>
# include <biu/concepts.hpp>
# include <fmt/format.h>
# include <fmt/ostream.h>

namespace biu
{
  namespace format::detail_
  {
    template <typename Char, Char... c> struct FormatLiteralHelper : protected BasicStaticString<Char, c...>
      {template <typename... Param> std::basic_string<Char> operator()(Param&&... param) const;};
  }
  inline namespace literals
    { template <typename Char, Char... c> consteval format::detail_::FormatLiteralHelper<Char, c...> operator""_f(); }

  namespace format::detail_
  {
    template <typename T> concept OptionalWrap
      = SpecializationOf<T, std::optional> || SpecializationOf<T, std::shared_ptr>
        || SpecializationOf<T, std::weak_ptr> || SpecializationOf<T, std::unique_ptr>
        || SpecializationOf<T, std::experimental::observer_ptr>;
    template <typename Wrap> struct UnderlyingTypeOfOptionalWrap;
    template <typename Wrap> requires requires() {typename Wrap::value_type;}
      struct UnderlyingTypeOfOptionalWrap<Wrap>
      {using Type = std::remove_cvref_t<typename Wrap::value_type>;};
    template <typename Wrap> requires requires() {typename Wrap::element_type;}
      struct UnderlyingTypeOfOptionalWrap<Wrap>
      {using Type = std::remove_cvref_t<typename Wrap::element_type>;};
    template <typename T, typename Char> struct FormatterReuseProxy
    {
      constexpr auto parse(fmt::basic_format_parse_context<Char>& ctx)
        -> typename fmt::basic_format_parse_context<Char>::iterator;
    };
    template <typename T, typename Char>
      requires (!SpecializationOf<T, std::weak_ptr> && std::default_initializable<fmt::formatter<T>>)
      struct FormatterReuseProxy<T, Char> : fmt::formatter<T, Char> {};
  }
  inline namespace stream_operators
  {
    template <typename Char, typename... Ts> requires (sizeof...(Ts) > 0) std::basic_ostream<Char>& operator<<
      (std::basic_ostream<Char>& os, const std::variant<Ts...>& value);
  }
}

namespace fmt
{
  template <typename Char, biu::format::detail_::OptionalWrap Wrap> struct formatter<Wrap, Char>
    : biu::format::detail_::FormatterReuseProxy
      <typename biu::format::detail_::UnderlyingTypeOfOptionalWrap<Wrap>::Type, Char>
  {
    template <typename FormatContext> auto format(const Wrap& wrap, FormatContext& ctx) const
      -> typename FormatContext::iterator;
  };

  template <biu::SpecializationOf<std::sub_match> SubMatch> struct formatter<SubMatch, typename SubMatch::value_type>
    : formatter<std::basic_string<typename SubMatch::value_type>, typename SubMatch::value_type>
  {
    template <typename FormatContext> auto format(const SubMatch& match, FormatContext& ctx) const
      -> typename FormatContext::iterator;
  };

  template <typename Char, biu::Enumerable T> struct formatter<T, Char>
  {
    bool full = false;
    constexpr auto parse(fmt::basic_format_parse_context<Char>& ctx)
      -> typename fmt::basic_format_parse_context<Char>::iterator;
    template <typename FormatContext> auto format(const T& value, FormatContext& ctx) const
      -> typename FormatContext::iterator;
  };

  template <typename Char, typename... Ts> struct formatter<std::variant<Ts...>, Char>
    : basic_ostream_formatter<Char> {};
}
