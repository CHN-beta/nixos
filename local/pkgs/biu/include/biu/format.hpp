# pragma once
# include <variant>
# include <experimental/memory>
# include <fmt/ostream.h>
# include <biu/string.hpp>
# include <biu/concepts.hpp>

namespace biu
{
	template <typename T, typename Char = char> concept Formattable = fmt::is_formattable<T, Char>::value;

	namespace detail_
	{
		template <typename Char, Char... c> struct FormatLiteralHelper : protected BasicStaticString<Char, c...>
			{template <typename... Param> std::basic_string<Char> operator()(Param&&... param) const;};
	}
	namespace literals
		{template <typename Char, Char... c> consteval detail_::FormatLiteralHelper<Char, c...> operator""_f();}

	namespace detail_
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
		template <typename T> struct FormatterReuseProxy
		{
			constexpr auto parse(fmt::format_parse_context& ctx)
				-> std::invoke_result_t<decltype(&fmt::format_parse_context::begin), fmt::format_parse_context>;
		};
		template <typename T>
			requires (!SpecializationOf<T, std::weak_ptr> && std::default_initializable<fmt::formatter<T>>)
			struct FormatterReuseProxy<T> : fmt::formatter<T> {};
	}
}

namespace std
{
	template <typename Char, typename... Ts> requires (sizeof...(Ts) > 0) basic_ostream<Char>& operator<<
		(basic_ostream<Char>& os, const variant<Ts...>& value);
}

namespace fmt
{
	using namespace biu::stream_operators;

	template <typename Char, biu::detail_::OptionalWrap Wrap> struct formatter<Wrap, Char>
		: biu::detail_::FormatterReuseProxy<typename biu::detail_::UnderlyingTypeOfOptionalWrap<Wrap>::Type>
	{
		template <typename FormatContext> auto format(const Wrap& wrap, FormatContext& ctx)
			-> std::invoke_result_t<decltype(&FormatContext::out), FormatContext>;
	};

	template <typename Char, biu::Enumerable T> struct formatter<T, Char>
	{
		bool full = false;
		constexpr auto parse(fmt::format_parse_context& ctx)
			-> std::invoke_result_t<decltype(&fmt::format_parse_context::begin), fmt::format_parse_context>;
		template <typename FormatContext> auto format(const T& value, FormatContext& ctx)
			-> std::invoke_result_t<decltype(&FormatContext::out), FormatContext>;
	};

	template <typename Char, typename... Ts> struct formatter<std::variant<Ts...>, Char>
		: basic_ostream_formatter<Char> {};
}
