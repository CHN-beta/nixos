# pragma once
# include <fmt/core.h>
# include <fmt/ranges.h>
# include <fmt/std.h>
# include <fmt/ostream.h>
# include <fmt/xchar.h>
# include <nameof.hpp>
# include <biu/format.hpp>

namespace biu
{
  template <typename Char, Char... c> template <typename... Param>
    std::basic_string<Char> format::detail_::FormatLiteralHelper<Char, c...>::operator() (Param&&... param) const
    { return fmt::format(BasicStaticString<Char, c...>::StringView, std::forward<Param>(param)...); }
  template <typename Char, Char... c> consteval
    format::detail_::FormatLiteralHelper<Char, c...> literals::operator""_f()
    { return {}; }

  template <typename T, typename Char> constexpr
    auto format::detail_::FormatterReuseProxy<T, Char>::parse(fmt::basic_format_parse_context<Char>& ctx)
    -> typename fmt::basic_format_parse_context<Char>::iterator
  {
    if (ctx.begin() != ctx.end() && *ctx.begin() != '}')
      throw fmt::format_error
      (
        "{} do not support to be format, so the wrapper should not have any format syntax."_f
          (nameof::nameof_full_type<T>())
      );
    return ctx.begin();
  }

  template <typename Char, typename... Ts> requires (sizeof...(Ts) > 0) std::basic_ostream<Char>&
    stream_operators::operator<<(std::basic_ostream<Char>& os, const std::variant<Ts...>& value)
  {
    using namespace biu::literals;
    auto try_print = [&]<typename T>
    {
      if (holds_alternative<T>(value))
      {
        if constexpr (fmt::is_formattable<T, Char>::value)
          os << "({}: {})"_f(nameof::nameof_full_type<T>(), get<T>(value));
        else os << "({}: {})"_f(nameof::nameof_full_type<T>(), "non-null unformattable value");
      }
    };
    (try_print.template operator()<Ts>(), ...);
    return os;
  }
}

namespace fmt
{
  template <typename Char, biu::format::detail_::OptionalWrap Wrap> template <typename FormatContext>
    auto formatter<Wrap, Char>::format(const Wrap& wrap, FormatContext& ctx) const
    -> typename FormatContext::iterator
  {
    using value_t = biu::format::detail_::UnderlyingTypeOfOptionalWrap<Wrap>::Type;
    auto format_value_type = [&, this](const value_t& value)
    {
      if constexpr (!fmt::is_formattable<value_t, Char>::value)
        return fmt::format_to(ctx.out(), "non-null unformattable value");
      else if constexpr (std::default_initializable<formatter<value_t>>)
        biu::format::detail_::FormatterReuseProxy<value_t, Char>::format(value, ctx);
      else fmt::format_to(ctx.out(), "{}", value);
    };
    fmt::format_to(ctx.out(), "(");
    if constexpr (biu::SpecializationOf<Wrap, std::optional>)
      { if (wrap) format_value_type(*wrap); else fmt::format_to(ctx.out(), "null"); }
    else if constexpr (biu::SpecializationOf<Wrap, std::weak_ptr>)
    {
      if (auto shared = wrap.lock())
        { fmt::format_to(ctx.out(), "{} ", ptr(shared.get())); format_value_type(*shared); }
      else fmt::format_to(ctx.out(), "null");
    }
    else
    {
      if (wrap) { fmt::format_to(ctx.out(), "{} ", ptr(wrap.get())); format_value_type(*wrap); }
      else fmt::format_to(ctx.out(), "null");
    }
    return fmt::format_to(ctx.out(), ")");
  }

  template <typename Char, biu::Enumerable T> constexpr auto formatter<T, Char>::parse
    (fmt::basic_format_parse_context<Char>& ctx) -> typename fmt::basic_format_parse_context<Char>::iterator
  {
    auto it = ctx.begin();
    if (it != ctx.end() && *it == 'f') { full = true; it++; }
    if (it != ctx.end() && *it != '}') throw format_error{"syntax error."};
    return it;
  }

  template <typename Char, biu::Enumerable T> template <typename FormatContext>
    auto formatter<T, Char>::format(const T& value, FormatContext& ctx) const -> typename FormatContext::iterator
  {
    if (full) return fmt::format_to(ctx.out(), "{}::{}", nameof::nameof_type<T>(), nameof::nameof_enum(value));
    else return fmt::format_to(ctx.out(), "{}", nameof::nameof_enum(value));
  }
}
