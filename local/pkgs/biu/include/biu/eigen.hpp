# pragma once
# include <vector>
# include <span>
# include <Eigen/Dense>
# include <biu/concepts.hpp>

namespace biu
{
  namespace detail_::eigen
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

    // helper operator| to specify the size of the destination container
    // usage: some_value | toEigen<Row, Col>
    template <std::size_t Row, std::size_t Col> struct ToEigenHelper {};
    template <std::size_t Row = unspecifiedSize, std::size_t Col = unspecifiedSize>
      inline constexpr ToEigenHelper<Row, Col> toEigen;
    // convert 1D standard container to Eigen::Vector
    // if no size is specified, convert std::vector to dynamic-size Eigen::Vector,
    //  std::array to fixed-size Eigen::Vector;
    // if size is std::dynamic_extent, always convert to dynamic-size Eigen::Vector
    // if size is specified as a number, convert to fixed-size Eigen::Vector if specified size equals the size of the
    //  input, otherwise throw an error
    template <template <int N> typename Callback, std::size_t ToSize> auto deduce_eigen_size(auto&& container);
    template <Arithmetic T, StandardContainer<T> From, std::size_t ToSize> auto operator|
      (const From&, const ToEigenHelper<ToSize, unspecifiedSize>&);
    // convert 2D standard container to Eigen::Matrix
    // the same rules as above apply
    // besides, all rows must have the same size, otherwise throw an error
    template
    <
      Arithmetic T, StandardContainer<T> FromPerRow, StandardContainer<FromPerRow> From,
      std::size_t ToRow, std::size_t ToCol
    >
      auto operator|(const From&, const ToEigenHelper<ToRow, ToCol>&);

    // TODO: implement fromEigen
  }

  inline namespace eigen { using detail_::eigen::toEigen; using detail_::eigen::operator|; }
}
