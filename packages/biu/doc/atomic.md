# Atomic

The `Atomic<T>` class provides a thread-safe wrapper for a value of type `T`. It uses a mutex and a condition variable to provide advanced synchronization features.

## Core Features

- **Thread-safe access**: Protects the underlying value with a mutex.
- **Conditional waiting**: Can wait for a condition to be met before accessing or modifying the value.
- **Timeouts**: Support for timeouts on waiting operations.
- **Guard-based locking**: RAII-style locking for manual access.

## Usage

### Simple Access

```cpp
Atomic<int> a(10);
int val = a.get(); // Get a copy
a = 20;            // Set value
```

### Apply a Function

```cpp
a.apply([](int& v) { v += 1; });
```

### Conditional Waiting

```cpp
// Wait until value is greater than 10, then add 1
a.apply([](int& v) { v += 1; }, [](const int& v) { return v > 10; });
```

### Locking with Guard

```cpp
{
    auto guard = a.lock();
    *guard += 5;
} // Mutex released here
```

## API Reference

### `Atomic<T>`

- `Atomic()`: Default constructor.
- `Atomic(auto&& value)`: Construct with an initial value.
- `ValueType get()`: Get a copy of the value.
- `operator ValueType()`: Implicit conversion to the underlying type.
- `apply(function, [condition], [timeout])`: Apply a function to the value, optionally waiting for a condition and/or a timeout.
- `wait(condition, [timeout])`: Wait until a condition is met.
- `lock([condition], [timeout])`: Returns a `Guard` object for manual access.

### `Atomic<T>::Guard`

An RAII object that holds the lock on the `Atomic` object.
- `operator*()`: Access the value.
- `operator->()`: Access the value's members.
- `value()`: Returns a reference to the value.
