# pragma once
# include <vector>
# include <span>
# include <Eigen/Dense>
# include <biu/concepts.hpp>

namespace biu
{
  namespace eigen
  {
    namespace detail_
    {
      // user-specified size of destination container: dynamic, unspecified(use default), or fixed
      constexpr std::size_t dynamicSize = std::dynamic_extent, unspecifiedSize = std::dynamic_extent - 1;
      static_assert(std::dynamic_extent == std::numeric_limits<std::size_t>::max());

      // supported types of standard containers
      template <typename T, typename Scalar> struct SpecializationOfArrayHelper : std::false_type {};
      template <typename Scalar, std::size_t N>
        struct SpecializationOfArrayHelper<std::array<Scalar, N>, Scalar> : std::true_type {};
      template <typename Scalar, std::size_t N>
        struct SpecializationOfArrayHelper<std::array<Scalar, N>, void> : std::true_type {};
      template <typename T, typename Scalar = void> concept SpecializationOfArray =
        SpecializationOfArrayHelper<T, Scalar>::value;
      template <typename T, typename Scalar> concept StandardContainer =
        SpecializationOf<T, std::vector, Scalar> || SpecializationOfArray<T, Scalar>;

      // deduce the size of the destination Eigen container
      // if no size is specified, convert std::vector to dynamic-size Eigen::Vector,
      //  std::array to fixed-size Eigen::Vector;
      // if size is std::dynamic_extent, always convert to dynamic-size Eigen::Vector
      // if size is specified as a number, convert to fixed-size Eigen::Vector if specified size equals the size of the
      //  input, otherwise throw an error
      // return deduced size if the size is deducible in compile time, otherwise return Empty
      template <std::size_t ToSize, typename Container> consteval auto deduce_eigen_size();

      // helper operator| to specify the size of the destination container
      template <std::size_t Row, std::size_t Col> struct ToEigenHelper {};
      template <std::size_t Size> struct FromEigenVectorHelper {};
      template <std::size_t Row, std::size_t Col> struct FromEigenMatrixHelper {};
      struct FromEigenHelper {};

      // convert 1D standard container to Eigen::Matrix, the second argument should always be unspecified
      template <typename From, std::size_t ToSize> auto operator|
        (const From&, const detail_::ToEigenHelper<ToSize, detail_::unspecifiedSize>&)
        requires (detail_::StandardContainer<From, typename From::value_type> && Arithmetic<typename From::value_type>);

      // convert 2D standard container to Eigen::Matrix
      template <typename From, std::size_t ToRow, std::size_t ToCol> auto operator|
        (const From&, const detail_::ToEigenHelper<ToRow, ToCol>&)
        requires
        (
          detail_::StandardContainer<From, typename From::value_type>
          && detail_::StandardContainer<typename From::value_type, typename From::value_type::value_type>
          && Arithmetic<typename From::value_type::value_type>
        );

      // convert 1D Eigen matrix to std::vector or std::array
      template <typename Vector, std::size_t ToSize> auto operator|
        (const Vector&, const detail_::FromEigenVectorHelper<ToSize>&);

      // convert 2D Eigen matrix to std::vector or std::array
      template <typename Matrix, std::size_t ToRow, std::size_t ToCol> auto operator|
        (const Matrix&, const detail_::FromEigenMatrixHelper<ToRow, ToCol>&);
      
      // 自动选择 fromEigenVector 还是 fromEigenMatrix
      // 如果行数或者列数 <= 1，那么选择 fromEigenVector，否则选择 fromEigenMatrix
      template <typename Matrix> auto operator|(const Matrix&, const detail_::FromEigenHelper&);
    }

    // usage: some_value | toEigen<Row, Col>
    template <std::size_t Row = detail_::unspecifiedSize, std::size_t Col = detail_::unspecifiedSize>
      inline constexpr detail_::ToEigenHelper<Row, Col> toEigen;
    template <std::size_t Size = detail_::unspecifiedSize>
      inline constexpr detail_::FromEigenVectorHelper<Size> fromEigenVector;
    template <std::size_t Row = detail_::unspecifiedSize, std::size_t Col = detail_::unspecifiedSize>
      inline constexpr detail_::FromEigenMatrixHelper<Row, Col> fromEigenMatrix;
    inline constexpr detail_::FromEigenHelper fromEigen;

    // test if a class is an eigen matrix
    namespace detail_
    {
      template <typename Matrix> class EigenMatrix : public std::false_type {};
      template <typename Scalar, int Rows, int Cols, int Options>
        class EigenMatrix<Eigen::Matrix<Scalar, Rows, Cols, Options>> : public std::true_type {};
    }
    template <typename Matrix> concept EigenMatrix = detail_::EigenMatrix<Matrix>::value;
  }
  using eigen::toEigen, eigen::fromEigenVector, eigen::fromEigenMatrix, eigen::fromEigen, eigen::EigenMatrix;
}

// archive a matrix
namespace Eigen
{
  template <typename Matrix> constexpr auto serialize(auto & archive, Matrix& matrix)
    requires biu::EigenMatrix<std::remove_cvref_t<Matrix>>;
}
