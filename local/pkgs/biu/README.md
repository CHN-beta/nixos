# `common`:

```c++
// get hash of any object
std::size_t hash(auto&&... objs);
// suppress unused variable warning
void unused(auto&&...);
// block forever
void block_forever();

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

