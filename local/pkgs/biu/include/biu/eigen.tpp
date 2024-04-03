# pragma once
# include <biu/eigen.hpp>
// # include <biu/logger.hpp>
# include <range/v3/view.hpp>

namespace biu
{

  namespace detail_
  {
    consteval int vector_size_to_eigen_size(std::size_t n)
      { return (n == unspecifiedSize || n == dynamicSize) ? Eigen::Dynamic : static_cast<int>(n); }
    template <std::size_t N> consteval int array_size_to_eigen_size(std::size_t n)
    {
      static_assert(n == dynamicSize || n == unspecifiedSize || n == N);
      return (n == dynamicSize) ? Eigen::Dynamic : static_cast<int>(N);
    }
  }
  template <Arithmetic T, std::size_t N> Eigen::Vector<T, detail_::vector_size_to_eigen_size(N)> operator|
    (const std::vector<T>& input, const detail_::ToEigenHelper<N, detail_::unspecifiedSize>&)
  {
    // TODO: check size mismatch
    using Vector = Eigen::Vector<T, detail_::vector_size_to_eigen_size(N)>;
    Vector result;
    if constexpr (N == detail_::dynamicSize || N == detail_::unspecifiedSize)
      result = Eigen::Map<Eigen::Vector<T, detail_::vector_size_to_eigen_size(N)>>(input.data(), input.size());
    else
      result = Eigen::Map<Eigen::Vector<T, detail_::vector_size_to_eigen_size(N)>>(input.data());
    return result;
  }
  template <Arithmetic T, std::size_t fromSize, std::size_t toSize>
    Eigen::Vector<T, detail_::array_size_to_eigen_size<fromSize>(toSize)> operator|
    (const std::array<T, fromSize>& input, const detail_::ToEigenHelper<toSize, detail_::unspecifiedSize>&)
  {
    using Vector = Eigen::Vector<T, detail_::array_size_to_eigen_size<fromSize>(toSize)>;
    Vector result;
    if constexpr (toSize == detail_::dynamicSize)
      result = Eigen::Map<Eigen::Vector<T, detail_::array_size_to_eigen_size<fromSize>(toSize)>>
        (input.data(), input.size());
    else
      result = Eigen::Map<Eigen::Vector<T, detail_::array_size_to_eigen_size<fromSize>(toSize)>>(input.data());
    return result;
  }
  // TODO: implement 2D conversion operators
}
