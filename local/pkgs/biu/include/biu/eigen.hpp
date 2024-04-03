# pragma once
# include <vector>
# include <span>
# include <Eigen/Dense>
# include <biu/concepts.hpp>

namespace biu
{
  namespace detail_
  {
    constexpr std::size_t dynamicSize = std::dynamic_extent, unspecifiedSize = std::dynamic_extent - 1;
    template <std::size_t M = unspecifiedSize, std::size_t N = unspecifiedSize> struct ToEigenHelper {};
    template <std::size_t M = unspecifiedSize, std::size_t N = unspecifiedSize> struct FromEigenHelper {};
  }
  // convert std::vector or std::array to Eigen::Vector or Eigen::Matrix
  template <std::size_t M = std::dynamic_extent, std::size_t N = std::dynamic_extent>
    inline constexpr detail_::ToEigenHelper<M, N> toEigen;
  // convert Eigen::Vector or Eigen::Matrix to std::vector or std::array
  inline constexpr detail_::FromEigenHelper fromEigen;

  // convert std::vector to Eigen::Vector
  // if no size is specified, the result is a dynamic-size Eigen::Vector
  // otherwise, the result is a fixed-size Eigen::Vector with specified size
  namespace detail_ { consteval int vector_size_to_eigen_size(std::size_t); }
  template <Arithmetic T, std::size_t N> Eigen::Vector<T, detail_::vector_size_to_eigen_size(N)> operator|
    (const std::vector<T>&, const detail_::ToEigenHelper<N, detail_::unspecifiedSize>&);
  // convert std::array to Eigen::Vector
  // if no size is specified, the result is a fixed-size Eigen::Vector with the same size as the input
  // otherwise, if std::dynamic_extent is specified, the result is a dynamic-size Eigen::Vector
  namespace detail_ { template <std::size_t N> consteval int array_size_to_eigen_size(std::size_t); }
  template <Arithmetic T, std::size_t fromSize, std::size_t toSize>
    Eigen::Vector<T, detail_::array_size_to_eigen_size<fromSize>(toSize)> operator|
    (const std::array<T, fromSize>&, const detail_::ToEigenHelper<toSize, detail_::unspecifiedSize>&);

  // 2D counterpart of the above
  template <Arithmetic T, std::size_t Row, std::size_t Col>
    Eigen::Matrix<T, detail_::vector_size_to_eigen_size(Row), detail_::vector_size_to_eigen_size(Col)> operator|
    (const std::vector<std::vector<T>>&, const detail_::ToEigenHelper<Row, Col>&);
  template <Arithmetic T, std::size_t RowFrom, std::size_t RowTo, std::size_t Col>
    Eigen::Matrix<T, detail_::array_size_to_eigen_size<RowFrom>(RowTo), detail_::vector_size_to_eigen_size(Col)>
    operator|(const std::array<std::vector<T>, RowFrom>&, const detail_::ToEigenHelper<RowTo, Col>&);
  template <Arithmetic T, std::size_t Row, std::size_t ColFrom, std::size_t ColTo>
    Eigen::Matrix<T, detail_::vector_size_to_eigen_size(Row), detail_::array_size_to_eigen_size<ColFrom>(ColTo)>
    operator|(const std::vector<std::array<T, ColFrom>>&, const detail_::ToEigenHelper<Row, ColTo>&);
  template <Arithmetic T, std::size_t RowFrom, std::size_t RowTo, std::size_t ColFrom, std::size_t ColTo>
    Eigen::Matrix<T, detail_::array_size_to_eigen_size<RowFrom>(RowTo),
      detail_::array_size_to_eigen_size<ColFrom>(ColTo)>
    operator|(const std::array<std::array<T, ColFrom>, RowFrom>&, const detail_::ToEigenHelper<RowTo, ColTo>&);
  
  // TODO: handle fromEigen
}
