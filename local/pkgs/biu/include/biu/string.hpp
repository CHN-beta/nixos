# pragma once
# include <regex>
# include <array>
# include <string>
# include <string_view>
# include <iostream>
# include <concurrencpp/concurrencpp.h>
# include <biu/concepts.hpp>
# include <biu/smartref.hpp>

namespace biu
{
	// Store a string in a static member of a class; or, use a class to represent a string.
	template <DecayedType Char, Char... c> struct BasicStaticString
	{
		static constexpr std::array<Char, sizeof...(c)> Array{c...};
		static constexpr std::basic_string_view<Char> StringView{Array.data(), sizeof...(c)};
	};
	template <char... c> using StaticString = BasicStaticString<char, c...>;
	inline namespace stream_operators
	{
		template <typename Char, Char... c>
			std::basic_ostream<Char>& operator<<(std::basic_ostream<Char>& os, BasicStaticString<Char, c...>);
	}
	inline namespace literals
		{ template <typename Char, Char... c> consteval BasicStaticString<Char, c...> operator""_ss(); }
	namespace detail_
	{
		template <typename C, typename T> struct SpecializationOfBasicStaticStringHelper : std::false_type {};
		template <typename C, C... c>
			struct SpecializationOfBasicStaticStringHelper<C, BasicStaticString<C, c...>> : std::true_type {};
		template <typename C, C... c>
			struct SpecializationOfBasicStaticStringHelper<void, BasicStaticString<C, c...>> : std::true_type {};
		template <typename T, typename C> concept SpecializationOfBasicStaticString
			= SpecializationOfBasicStaticStringHelper<std::decay_t<C>, std::decay_t<T>>::value;
	}
	template <typename T, typename C = void> concept SpecializationOfBasicStaticString
		= detail_::SpecializationOfBasicStaticString<T, C>
			&& detail_::SpecializationOfBasicStaticString<T, void>;
	template <typename T> concept SpecializationOfStaticString = SpecializationOfBasicStaticString<T, char>;

	// Store a string in a fixed-size array
	template <DecayedType Char, std::size_t N> struct BasicFixedString
	{
		Char Data[N];
		constexpr static const std::size_t Size = N - 1;
		constexpr BasicFixedString(const Char (&str)[N]);
	};
	template <std::size_t N> using FixedString = BasicFixedString<char, N>;
	inline namespace stream_operators
	{
		template <typename Char, std::size_t N> std::basic_ostream<Char>& operator<<
			(std::basic_ostream<Char>& os, const BasicFixedString<Char, N>& str);
	}
	inline namespace literals { template <BasicFixedString FS> constexpr decltype(FS) operator""_fs(); }
	namespace detail_
	{
		template <typename C, typename T> struct SpecializationOfBasicFixedStringHelper : std::false_type {};
		template <typename C, std::size_t N>
			struct SpecializationOfBasicFixedStringHelper<C, BasicFixedString<C, N>> : std::true_type {};
		template <typename C, std::size_t N>
			struct SpecializationOfBasicFixedStringHelper<void, BasicFixedString<C, N>> : std::true_type {};
		template <typename T, typename C> concept SpecializationOfBasicFixedString
			= SpecializationOfBasicFixedStringHelper<std::decay_t<C>, std::decay_t<T>>::value;
	}
	template <typename T, typename C = void> concept SpecializationOfBasicFixedString
		= detail_::SpecializationOfBasicFixedString<T, C>
			&& detail_::SpecializationOfBasicFixedString<T, void>;
	template <typename T> concept SpecializationOfFixedString = SpecializationOfBasicFixedString<T, char>;

	// Store a string with at most N characters
	template <DecayedType Char, std::size_t N> struct BasicVariableString
	{
		Char Data[N];
		std::size_t Size;
		constexpr static const std::size_t MaxSize = N - 1;
		template <std::size_t M> requires (M<=N) constexpr BasicVariableString(const Char (&str)[M]);
	};
	template <std::size_t N> using VariableString = BasicVariableString<char, N>;
	inline namespace stream_operators
	{
		template <typename Char, std::size_t N> std::basic_ostream<Char>& operator<<
			(std::basic_ostream<Char>& os, const BasicVariableString<Char, N>& str);
	}

	namespace detail_
	{
		template <typename C, typename T> struct SpecializationOfBasicVariableStringHelper : std::false_type {};
		template <typename C, std::size_t N>
			struct SpecializationOfBasicVariableStringHelper<C, BasicVariableString<C, N>> : std::true_type {};
		template <typename C, std::size_t N>
			struct SpecializationOfBasicVariableStringHelper<void, BasicVariableString<C, N>> : std::true_type {};
		template <typename T, typename C> concept SpecializationOfBasicVariableString
			= SpecializationOfBasicVariableStringHelper<std::decay_t<C>, std::decay_t<T>>::value;
	}
	template <typename T, typename C = void> concept SpecializationOfBasicVariableString
		= detail_::SpecializationOfBasicVariableString<T, C>
			&& detail_::SpecializationOfBasicVariableString<T, void>;
	template <typename T> concept SpecializationOfVariableString = SpecializationOfBasicVariableString<T, char>;

	namespace string
	{
		// Find specific content in a string. Return unmatched content before the match and the match result every
		// time. If match reached the end, the second returned value will be std::sregex_iterator().
		concurrencpp::generator<std::pair<std::string_view, std::sregex_iterator>> find
			(SmartRef<const std::string> data, SmartRef<const std::regex> regex);
		// Use a regex to find all matches and replace them with a callback function
		std::string replace
			(const std::string& data, const std::regex& regex, std::function<std::string(const std::smatch&)> function);
	}
}
