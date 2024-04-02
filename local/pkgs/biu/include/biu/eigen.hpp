# pragma once
# include <vector>
# include <Eigen/Dense>
# include <biu/concepts.hpp>

namespace biu
{
  namespace detail_
  {
    template <std::size_t M, std::size_t N = 1> struct ToEigenHelper {};
    struct FromEigenHelper {};
    consteval int eigen_size(std::size_t n);
  }
  template <std::size_t M, std::size_t N = 1> inline constexpr detail_::ToEigenHelper<M, N> toEigen;
  inline constexpr detail_::FromEigenHelper fromEigen;

  template <Arithmetic T, std::size_t N> Eigen::Vector<T, detail_::eigen_size(N)> operator|
    (const std::vector<T>& input, const detail_::ToEigenHelper<N>&);
  template <Arithmetic T, std::size_t M, std::size_t N>
    Eigen::Matrix<T, detail_::eigen_size(M), detail_::eigen_size(N)> operator|
    (const std::vector<std::vector<T>>& input, const detail_::ToEigenHelper<M, N>&);
  template <Arithmetic T, int M, int N> std::conditional_t<N == 1, std::vector<T>, std::vector<std::vector<T>>>
    operator|(const Eigen::Matrix<T, M, N>& input, const detail_::FromEigenHelper&);
}
