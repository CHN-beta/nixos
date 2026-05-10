# Eigen Integration

The `eigen` module provides seamless integration between the Eigen library and C++ standard containers.

## Core Feature: Piping to Eigen

You can convert `std::vector` or `std::array` to Eigen matrices and vectors using the `| toEigen` operator.

### Conversion to Eigen

```cpp
std::vector<double> v = {1.0, 2.0, 3.0};

// Convert to Eigen::VectorXd
auto ev = v | toEigen;

// Convert to fixed-size Eigen::Vector3d
auto ev3 = v | toEigen<3>;

// Convert 2D vector to Eigen::MatrixXd
std::vector<std::vector<double>> m = {{1, 2}, {3, 4}};
auto em = m | toEigen;
```

### Conversion from Eigen

You can convert Eigen objects back to standard containers using `| fromEigen`, `| fromEigenVector`, or `| fromEigenMatrix`.

```cpp
Eigen::MatrixXd em = ...;

// Convert to std::vector<std::vector<double>>
auto m = em | fromEigen;

// Convert to std::vector<double> (if it's a vector)
auto v = em | fromEigenVector;
```

## Serialization

The module provides a `serialize` function for Eigen matrices, allowing them to be used with the `biu::serialize` module.

## API Reference

- `toEigen<Row, Col>`: Helper for converting to Eigen.
- `fromEigenVector<Size>`: Helper for converting from an Eigen vector to a standard container.
- `fromEigenMatrix<Row, Col>`: Helper for converting from an Eigen matrix to a standard container.
- `fromEigen`: Automatically chooses between vector or matrix conversion.
- `concept EigenMatrix<T>`: A concept that checks if a type is an Eigen matrix.
