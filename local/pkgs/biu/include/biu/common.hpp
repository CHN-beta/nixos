# pragma once
# include <regex>
# include <fmt/format.h>
# include <magic_enum.hpp>

namespace biu
{
	std::size_t hash(auto&&... objs);
	[[gnu::always_inline]] void unused(auto&&...);

	using uint128_t = __uint128_t;

	inline namespace literals
	{
		using namespace std::literals;
		using namespace fmt::literals;
		std::regex operator""_re(const char* str, std::size_t len);
	}

	inline namespace stream_operators { using namespace magic_enum::iostream_operators; }

	struct CaseInsensitiveStringLessComparator
	{
		template <typename String> constexpr bool operator()(const String& s1, const String& s2) const;
	};

	namespace detail_
	{
		template <typename T> struct RemoveMemberPointerHelper { using Type = T; };
		template <typename Class, typename Member> struct RemoveMemberPointerHelper<Member Class::*>
			{ using Type = Member; };
	}
	template <typename MemberPointer> using RemoveMemberPointer
		= typename detail_::RemoveMemberPointerHelper<MemberPointer>::Type;

	[[noreturn]] void block_forever();

	namespace detail_
	{
		template <typename From, typename To> struct MoveQualifiersHelper
		{
			protected: static constexpr bool Const_ = std::is_const_v<From>;
			protected: static constexpr bool Volatile_ = std::is_volatile_v<From>;
			protected: static constexpr bool Reference_ = std::is_reference_v<From>;
			protected: static constexpr bool Lvalue_ = std::is_lvalue_reference_v<From>;
			protected: using NoCvrefType_ = std::remove_cvref_t<To>;
			protected: using NoCvType_
				= std::conditional_t<Reference_, std::conditional_t<Lvalue_, NoCvrefType_&, NoCvrefType_&&>, NoCvrefType_>;
			protected: using NoConstType_ = std::conditional_t<Volatile_, volatile NoCvType_, NoCvType_>;
			public: using Type = std::conditional_t<Const_, const NoConstType_, NoConstType_>;
		};
	}
	template <typename From, typename To> using MoveQualifiers
		= typename detail_::MoveQualifiersHelper<From, To>::Type;

	namespace detail_
	{
		template <typename T, typename Fallback = void> struct FallbackIfNoTypeDeclaredHelper { using Type = Fallback; };
		template <typename T, typename Fallback> requires requires { typename T::Type; }
			struct FallbackIfNoTypeDeclaredHelper<T, Fallback> { using Type = typename T::Type; };
		template <typename T, typename Fallback> requires requires {typename T::type;}
			struct FallbackIfNoTypeDeclaredHelper<T, Fallback> { using Type = typename T::type; };
	}
	template <typename T, typename Fallback = void> using FallbackIfNoTypeDeclared
		= typename detail_::FallbackIfNoTypeDeclaredHelper<T, Fallback>::Type;
}
