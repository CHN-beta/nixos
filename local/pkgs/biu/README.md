# `common`:

```c++
// get hash of any object
std::size_t hash(auto&&... objs);
// suppress unused variable warning
void unused(auto&&...);
// block forever
void block_forever();
detail_::ExecResult exec
(
  std::filesystem::path program, std::vector<std::string> args, std::optional<std::string> stdin,
  std::map<std::string, std::string> extra_env
);

using int128_t = ...;
using uint128_t = ...;

struct CaseInsensitiveStringLessComparator {...};

// remove Class::*
template <typename MemberPointer> using RemoveMemberPointer = ...;
// move qualifiers (cvref) from From to To
template <typename From, typename To> using MoveQualifiers = ...;
// get T::type or T::Type if exists, otherwise Fallback
template <typename T, typename Fallback = void> using FallbackIfNoTypeDeclared
```

# `inline literals`

```c++
using namespace std::literals;
using namespace fmt::literals;
std::regex operator""_re(const char* str, std::size_t len);
```

# `inline stream_operators`:

```c++
inline namespace stream_operators { using namespace magic_enum::iostream_operators; }
```

# `env`

```c++
bool is_interactive();
std::optional<std::string> env(std::string name);
std::map<std::string, std::string> env();
```
