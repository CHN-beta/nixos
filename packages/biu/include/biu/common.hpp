# pragma once
# include <regex>
# include <optional>
# include <filesystem>
# include <concurrencpp/concurrencpp.h>
# include <type_traits>
# include <fmt/format.h>
# include <magic_enum_all.hpp>

namespace biu
{
  inline namespace literals
  {
    using namespace std::literals;
    using namespace fmt::literals;
    std::regex operator""_re(const char* str, std::size_t len);
  }
  inline namespace stream_operators { using namespace magic_enum::iostream_operators; }
  namespace common
  {
    std::size_t hash(auto&&... objs);
    [[gnu::always_inline]] void unused(auto&&...);
    [[noreturn]] void block_forever();

    bool is_interactive();
    std::optional<std::string> env(std::string name);

    using int128_t = __int128_t;
    using uint128_t = __uint128_t;

    struct Empty
    {
      template <typename T> consteval bool operator==(const T&) const
        { return std::same_as<std::remove_cvref_t<T>, Empty>; }
    };

    struct CaseInsensitiveStringLessComparator
      { template <typename String> constexpr bool operator()(const String& s1, const String& s2) const; };
    namespace detail_
    {
      template <typename T> struct RemoveMemberPointerHelper { using Type = T; };
      template <typename Class, typename Member> struct RemoveMemberPointerHelper<Member Class::*>
        { using Type = Member; };
    }
    template <typename MemberPointer> using RemoveMemberPointer
      = typename detail_::RemoveMemberPointerHelper<MemberPointer>::Type;

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

    namespace detail_
    {
      struct ExecMode { bool DirectStdin = false, DirectStdout = false, DirectStderr = false, SearchPath = false; };
      template <ExecMode Mode> struct ExecResult
      {
        int ExitCode;
        std::conditional_t<Mode.DirectStdout, Empty, std::string> Stdout;
        std::conditional_t<Mode.DirectStderr, Empty, std::string> Stderr;
        operator bool() const;
      };
      template <ExecMode Mode> struct ExecInput
      {
        std::conditional_t<Mode.SearchPath, std::string, std::filesystem::path> Program;
        std::vector<std::string> Args;
        std::conditional_t<Mode.DirectStdin, Empty, std::string> Stdin = {};
        std::map<std::string, std::string> ExtraEnv = {};
        std::optional<std::chrono::milliseconds> Timeout;
      };
    }
    template <detail_::ExecMode Mode = {}> detail_::ExecResult<Mode> exec(detail_::ExecInput<Mode> input);

    template <typename Array> concurrencpp::generator<std::pair<Array, std::size_t>> sequence(Array from, Array to);
    template <typename Array> concurrencpp::generator<std::pair<Array, std::size_t>> sequence(Array to);

    namespace detail_
    {
      template <typename Byte> struct ReadReturnType;
      template <> struct ReadReturnType<std::byte> { using Type = std::vector<std::byte>; };
      template <> struct ReadReturnType<char> { using Type = std::string; };
    }
    template <typename Byte> detail_::ReadReturnType<Byte>::Type read(const std::filesystem::path& path);
    template <typename Byte> detail_::ReadReturnType<Byte>::Type read(std::istream& input);
    template<> std::vector<std::byte> read<std::byte>(const std::filesystem::path& path);
    template<> std::string read<char>(const std::filesystem::path& path);
    template<> std::vector<std::byte> read<std::byte>(std::istream& input);
    template<> std::string read<char>(std::istream& input);

    namespace detail_
    {
      struct ToLvalueHelper {};
      template <typename T> T& operator|(T&& obj, const ToLvalueHelper&);
    }
    constexpr detail_::ToLvalueHelper toLvalue;
  }
  using common::hash, common::unused, common::block_forever, common::is_interactive, common::env, common::int128_t,
    common::uint128_t, common::Empty, common::CaseInsensitiveStringLessComparator, common::RemoveMemberPointer,
    common::MoveQualifiers, common::FallbackIfNoTypeDeclared, common::exec, common::sequence, common::read,
    common::toLvalue;
}
