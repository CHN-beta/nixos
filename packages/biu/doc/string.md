# String Utilities

The `string` namespace provides specialized string types and enhanced regex utilities.

## Specialized String Types

- `StaticString<char... c>`: A compile-time string stored as a template parameter.
- `FixedString<N>`: A fixed-size string stored in a character array of size `N`.
- `VariableString<N>`: A string with a maximum capacity of `N-1` characters.

These types are useful for compile-time constants and avoiding heap allocations.

### Literals

- `_ss`: Literal for `StaticString`. Example: `"hello"_ss`.
- `_fs`: Literal for `FixedString`. Example: `"world"_fs`.

## Regex Utilities

- `biu::string::find(data, regex)`: A generator that yields pairs of `(unmatched_prefix, match_result)`.
- `biu::string::replace(data, regex, function)`: Replaces matches of a regex using a transformation function.

### Example of `find`

```cpp
for (auto [prefix, match] : biu::string::find(text, regex)) {
    // prefix: content before the match
    // match: the std::sregex_iterator for the current match
}
```

## Stream Operators

All specialized string types support the `<<` operator for output streams.
