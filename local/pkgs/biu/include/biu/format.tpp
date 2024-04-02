# pragma once
# include <nameof.hpp>
# include <biu/format.hpp>

namespace biu
{
	template <typename Char, Char... c> template <typename... Param>
		std::basic_string<Char> detail_::FormatLiteralHelper<Char, c...>::operator() (Param&&... param) const
		{return fmt::format(BasicStaticString<Char, c...>::StringView, std::forward<Param>(param)...);}
	template <typename Char, Char... c> consteval
		detail_::FormatLiteralHelper<Char, c...> literals::operator""_f()
		{return {};}

	template <typename T> constexpr
		auto detail_::FormatterReuseProxy<T>::parse(fmt::format_parse_context& ctx)
		-> std::invoke_result_t<decltype(&fmt::format_parse_context::begin), fmt::format_parse_context>
	{
		if (ctx.begin() != ctx.end() && *ctx.begin() != '}')
			throw fmt::format_error
			(
				"{} do not support to be format, so the wrapper should not have any format syntax."_f
					(nameof::nameof_full_type<T>())
			);
		return ctx.begin();
	}
}

namespace std
{
	template <typename Char, typename... Ts> requires (sizeof...(Ts) > 0)
		basic_ostream<Char>& operator<<(basic_ostream<Char>& os, const variant<Ts...>& value)
	{
		using namespace biu::literals;
		auto try_print = [&]<typename T>
		{
			if (holds_alternative<T>(value))
			{
				if constexpr (biu::Formattable<T, Char>)
					os << "({}: {})"_f(nameof::nameof_full_type<T>(), get<T>(value));
				else
					os << "({}: {})"_f(nameof::nameof_full_type<T>(), "non-null unformattable value");
			}
		};
		(try_print.template operator()<Ts>(), ...);
		return os;
	}
}

namespace fmt
{
	template <typename Char, biu::detail_::OptionalWrap Wrap> template <typename FormatContext>
		auto formatter<Wrap, Char>::format(const Wrap& wrap, FormatContext& ctx)
		-> std::invoke_result_t<decltype(&FormatContext::out), FormatContext>
	{
		using namespace biu::literals;
		using namespace biu::stream_operators;
		using value_t = biu::detail_::UnderlyingTypeOfOptionalWrap<Wrap>::Type;
		auto format_value_type = [&, this](const value_t& value)
		{
			if constexpr (!biu::Formattable<value_t, Char>)
				return format_to(ctx.out(), "non-null unformattable value");
			else if constexpr (std::default_initializable<formatter<value_t>>)
				biu::detail_::FormatterReuseProxy<value_t>::format(value, ctx);
			else
				format_to(ctx.out(), "{}", value);
		};
		format_to(ctx.out(), "(");
		if constexpr (biu::SpecializationOf<Wrap, std::optional>)
		{
			if (wrap)
				format_value_type(*wrap);
			else
				format_to(ctx.out(), "null");
		}
		else if constexpr (biu::SpecializationOf<Wrap, std::weak_ptr>)
		{
			if (auto shared = wrap.lock())
			{
				format_to(ctx.out(), "{} ", ptr(shared.get()));
				format_value_type(*shared);
			}
			else
				format_to(ctx.out(), "null");
		}
		else
		{
			if (wrap)
			{
				format_to(ctx.out(), "{} ", ptr(wrap.get()));
				format_value_type(*wrap);
			}
			else
				format_to(ctx.out(), "null");
		}
		return format_to(ctx.out(), ")");
	}

	template <typename Char, biu::Enumerable T> constexpr
		auto formatter<T, Char>::parse(format_parse_context& ctx)
		-> std::invoke_result_t<decltype(&format_parse_context::begin), format_parse_context>
	{
		auto it = ctx.begin();
		if (it != ctx.end() && *it == 'f')
		{
			full = true;
			it++;
		}
		if (it != ctx.end() && *it != '}')
			throw format_error{"syntax error."};
		return it;
	}

	template <typename Char, biu::Enumerable T> template <typename FormatContext>
		auto formatter<T, Char>::format(const T& value, FormatContext& ctx)
		-> std::invoke_result_t<decltype(&FormatContext::out), FormatContext>
	{
		if (full)
			return format_to(ctx.out(), "{}::{}", nameof::nameof_type<T>(), nameof::nameof_enum(value));
		else
			return format_to(ctx.out(), "{}", nameof::nameof_enum(value));
	}
}
