# Logger

The `Logger` class provides a thread-safe logging system with advanced features like object lifetime monitoring and function execution tracing.

## Initialization

```cpp
// Initialize with a stream and log level
Logger::init(std::experimental::make_observer(&std::cout), Logger::Level::Debug);
```

On Linux, you can also initialize Telegram notifications:
```cpp
Logger::telegram_init("TOKEN", "CHAT_ID");
Logger::telegram_notify("System started");
```

## Log Levels

- `None`
- `Error`
- `Info`
- `Debug`

## Function Guard

`Logger::Guard` tracks the execution of a function. It logs when the function starts, when it ends (including duration), and can log return values.

```cpp
void my_function(int x) {
    Logger::Guard guard(x); // Logs entry
    // ...
    guard(); // Log "reached" marker
    // ...
    return guard.rtn(42); // Logs exit with return value and duration
}
```

## Object Monitor

`Logger::ObjectMonitor` tracks the lifetime of objects.

```cpp
struct MyClass : protected Logger::ObjectMonitor<MyClass> {
    // Logs creation and destruction (with duration) automatically
};
```

## Direct Logging

Inside a `Guard` context, you can use:
- `guard.error(message)`
- `guard.info(message)`
- `guard.debug(message)`

These functions include stacktrace information and indentation based on the call depth.
