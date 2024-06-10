# pragma once
# include <regex>
# include <optional>
# include <filesystem>
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

    struct Empty {};

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
      template <bool DirectStdout, bool DirectStderr> struct ExecResult
      {
        int exit_code;
        std::conditional_t<DirectStdout, Empty, std::string> std_out;
        std::conditional_t<DirectStderr, Empty, std::string> std_err;
      };
      struct ExecInput { bool DirectStdin = false, DirectStdout = false, DirectStderr = false, SearchPath = false; };
    }
    template <detail_::ExecInput Input = {}> requires (!Input.DirectStdin)
      detail_::ExecResult<Input.DirectStdout, Input.DirectStderr> exec
    (
      std::conditional_t<Input.SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
      std::optional<std::string> stdin_string = {}, std::map<std::string, std::string> extra_env = {}
    );
    template <detail_::ExecInput Input = {}> requires (Input.DirectStdin)
      detail_::ExecResult<Input.DirectStdout, Input.DirectStderr> exec
    (
      std::conditional_t<Input.SearchPath, std::string, std::filesystem::path> program, std::vector<std::string> args,
      std::map<std::string, std::string> extra_env = {}
    );
  }
  using common::hash, common::unused, common::block_forever, common::is_interactive, common::env, common::int128_t,
    common::uint128_t, common::Empty, common::CaseInsensitiveStringLessComparator, common::RemoveMemberPointer,
    common::MoveQualifiers, common::FallbackIfNoTypeDeclared, common::exec;
}
