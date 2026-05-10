# BIU C++ Library Documentation

`biu` is a comprehensive C++20 library providing a wide range of utilities for modern C++ development, including thread-safe primitives, logging, string manipulation, process management, and integrations with popular libraries like Eigen, HighFive (HDF5), and yaml-cpp.

## Modules

- [**Common**](common.md): General purpose utilities, environment access, and file I/O.
- [**Atomic**](atomic.md): Thread-safe value wrapper with advanced locking and synchronization features.
- [**String**](string.md): Compile-time and fixed-size string types, and enhanced regex utilities.
- [**Format**](format.md): Extensions to the `{fmt}` library for formatting standard and third-party types.
- [**Logger**](logger.md): Thread-safe logging with stacktrace support, function guards, and object monitoring.
- [**Process**](process.md): High-level process execution and management.
- [**Eigen Integration**](eigen.md): seamless conversions between Eigen matrices/vectors and standard containers.
- [**YAML Integration**](yaml.md): Custom `yaml-cpp` converters for common types and Eigen objects.
- [**Other Utilities**](other.md): FFT, HDF5, Serialization, SmartRef, and custom Concepts.

## Basic Usage

Include the main header to access most features:

```cpp
#include <biu.hpp>

int main() {
    using namespace biu;
    // Your code here
}
```
