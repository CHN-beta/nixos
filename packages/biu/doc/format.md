# Format Extensions

The `format` module extends the `{fmt}` library to support additional types and provides a convenient formatting literal.

## Formatting Literal

- `_f`: A literal for formatting strings. Example: `"Hello, {}!"_f("world")` returns a `std::string`.

## Supported Types

`biu` provides `fmt::formatter` specializations for:

- **Optional and Pointers**: `std::optional`, `std::shared_ptr`, `std::unique_ptr`, `std::weak_ptr`, and `std::experimental::observer_ptr`. If the pointer is not null, it formats the underlying value.
- **Enums**: Any enum type (via `magic_enum`).
- **Variants**: `std::variant`.
- **Regex Sub-matches**: `std::sub_match`.
- **YAML Nodes**: `YAML::Node` from `yaml-cpp`.
- **Stacktraces**: `boost::stacktrace::basic_stacktrace`.

## Variant Stream Operator

`biu` also provides an `operator<<` for `std::variant` to make it easily printable to standard streams.
