# Process Management

The `process` module provides a high-level wrapper for executing and managing external processes using Boost.Asio.

## Execution

The `exec` function is the primary interface for running processes. It uses a configuration-based approach via the `ExecMode` and `ExecInput` structures.

### Basic Usage

```cpp
using namespace biu::process;

auto result = exec({
    .Program = "/usr/bin/ls",
    .Args = {"-l", "/home"}
});

if (result) {
    // Process finished successfully
    std::cout << "Exit code: " << result.ExitCode << std::endl;
}
```

### Capturing Output

To capture stdout or stderr as strings, set the `IoType` in the `ExecMode`.

```cpp
auto result = exec<{.Stdout = IoType::String, .Stderr = IoType::String}>({
    .Program = "grep",
    .Args = {"pattern", "file.txt"}
});

std::cout << "Output: " << result.Stdout << std::endl;
```

### Advanced Features

- **Search Path**: Set `.SearchPath = true` in `ExecMode` to search for the program in the system PATH.
- **Modify Environment**: Provide `.ExtraEnv` in `ExecInput` to add or modify environment variables for the child process.
- **Timeout**: Set `.Timeout` in `ExecInput` to limit the execution time.
- **Input Redirection**: Set `.Stdin` to `IoType::String` and provide data in `ExecInput.Stdin`.

## API Reference

- `enum class IoType { Direct, Close, String }`: Defines how to handle process I/O.
- `struct ExecMode`: Compile-time configuration for execution behavior.
- `struct ExecInput`: Runtime input for the process (program, args, env, timeout, etc.).
- `struct ExecResult`: Result of the process execution (exit code, output strings, etc.).
