# Common Utilities

The `common` namespace provides various general-purpose utilities, environment access, and file I/O helpers.

## General Utilities

- `std::size_t hash(auto&&... objs)`: Returns a hash of any number of objects.
- `void unused(auto&&...)`: Suppresses unused variable warnings.
- `[[noreturn]] void block_forever()`: Blocks the current thread indefinitely.
- `using int128_t = __int128_t`: 128-bit signed integer.
- `using uint128_t = __uint128_t`: 128-bit unsigned integer.
- `struct Empty`: A tag type that compares equal to itself.
- `CaseInsensitiveStringLessComparator`: A comparator for case-insensitive string comparison.

## Template Metaprogramming

- `RemoveMemberPointer<T>`: Removes the member pointer part of a type (e.g., `int Class::*` becomes `int`).
- `MoveQualifiers<From, To>`: Moves cv-qualifiers and references from one type to another.
- `FallbackIfNoTypeDeclared<T, Fallback>`: Returns `T::Type` or `T::type` if it exists, otherwise `Fallback`.

## Environment and Shell

- `bool is_interactive()`: Checks if the current session is interactive.
- `std::optional<std::string> env(std::string name)`: Gets an environment variable value.
- `std::map<std::string, std::string> env()`: Gets all environment variables.

## File I/O

- `std::string read<char>(const std::filesystem::path& path)`: Reads a file into a string.
- `std::vector<std::byte> read<std::byte>(const std::filesystem::path& path)`: Reads a file into a byte vector.
- `std::string read<char>(std::istream& input)`: Reads from a stream into a string.

## Other Helpers

- `sequence(from, to)`: A generator that yields pairs of `(value, index)` for a range.
- `for_each(function, args...)`: Applies a function to each argument.
- `toLvalue`: A helper used with `|` to force an rvalue to be treated as an lvalue reference.
- `perfect_return(obj)`: A helper for returning objects while preserving their value category.

## Literals

The `biu::literals` namespace provides:
- `_re`: Literal for `std::regex`.
- Re-exports of `std::literals` and `fmt::literals`.
