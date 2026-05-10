# Other Utilities

This page covers several smaller but useful modules in the `biu` library.

## FFT (Fast Fourier Transform)

The `fft` module provides simple forward and backward FFT functions using the `pocketfft` library.

- `std::vector<std::complex<T>> forward(std::vector<T> input)`: Forward FFT.
- `std::vector<T> backward(std::vector<std::complex<T>> input, [output_size])`: Backward FFT.

## HDF5 Integration

The `hdf5` module provides a simplified wrapper around `HighFive` for reading and writing HDF5 files.

- `Hdf5file(filename, [truncate])`: Open or create an HDF5 file.
- `read<T>(name)` / `read(name, object)`: Read a dataset into an object.
- `write<T>(name, object)`: Write an object to a dataset.
- `PhonopyComplex`: A helper struct for compatibility with Phonopy-style complex numbers in HDF5.

## Serialization

The `serialize` module provides a simple interface for serializing and deserializing objects.

- `std::vector<std::byte> serialize<std::byte>(const T& data)`
- `std::string serialize<char>(const T& data)`
- `T deserialize<T>(const std::string& or std::vector<std::byte>& data)`

## SmartRef

`SmartRef<T>` is a utility class that can store either a reference to an existing lvalue or a value moved/copied from an rvalue. It provides a unified way to handle both cases without unnecessary copies.

- `operator*()` and `operator->()`: Access the underlying object.

## Concepts

The `concepts` module defines several useful C++20 concepts:

- `DecayedType<T>`: `std::decay_t<T>` is the same as `T`.
- `SpecializationOf<T, Template>`: `T` is a specialization of the given template.
- `Arithmetic<T>`: `T` is an arithmetic type or a `std::complex` type.
- `Enumerable<T>`: `T` is an enum type.
- `Set<T>`: `T` is one of the standard set types or `boost::container::flat_set`.
- `ConvertibleTo<From, To>` / `ConvertibleFrom<To, From>`: Checks if types are convertible (implicitly or explicitly).
