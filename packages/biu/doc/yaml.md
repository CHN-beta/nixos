# YAML Integration

The `yaml` module provides custom `YAML::convert` specializations for common C++ types and library-specific objects, allowing them to be easily loaded from and saved to YAML files using `yaml-cpp`.

## Supported Types

`biu` extends `yaml-cpp` to support:

- **Eigen Matrices and Vectors**: Automatic conversion between Eigen types and YAML sequences/nested sequences.
- **Complex Numbers**: `std::complex<T>`.
- **Optional and Pointers**: `std::optional<T>`, `std::unique_ptr<T>`.
- **Sets**: `std::set`, `std::unordered_set`, `std::multiset`, `std::unordered_multiset`, and `boost::container::flat_set`.
- **Enums**: Automatic conversion using `magic_enum`.

## Usage

Simply use the standard `yaml-cpp` API:

```cpp
#include <biu/yaml.tpp>

YAML::Node node = ...;
auto matrix = node["my_matrix"].as<Eigen::MatrixXd>();

std::optional<int> opt = node["maybe_int"].as<std::optional<int>>();
```

## YamlParsable

The `biu::YamlParsable` tag can be used to indicate that a type is intended to be parsed from YAML, though most conversions are provided automatically for supported types.
