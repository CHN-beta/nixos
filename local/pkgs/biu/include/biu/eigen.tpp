# pragma once
# include <span>
# include <ranges>
# include <biu/eigen.hpp>
// # include <biu/logger.hpp>
# include <range/v3/view.hpp>

namespace biu
{
  consteval int detail_::eigen_size(std::size_t n)
    { return n == std::dynamic_extent ? Eigen::Dynamic : static_cast<int>(n); }
  template <Arithmetic T, std::size_t N> inline Eigen::Vector<T, detail_::eigen_size(N)> operator|
    (const std::vector<T>& input, const detail_::ToEigenHelper<N>&)
  {
    if constexpr (N == std::dynamic_extent)
      return { input.data(), input.size() };
    else
      return { input.data() };
  }
  template <Arithmetic T, std::size_t M, std::size_t N>
    inline Eigen::Matrix<T, detail_::eigen_size(M), detail_::eigen_size(N)> operator|
    (const std::vector<std::vector<T>>& input, const detail_::ToEigenHelper<M, N>&)
  {
    Eigen::Matrix<T, detail_::eigen_size(M), detail_::eigen_size(N)> output;
    if constexpr (M == std::dynamic_extent || N == std::dynamic_extent)
    {
      if constexpr (M != std::dynamic_extent)
        output.resize(M, input.size() > 0 ? input[0].size() : 0);
      else if constexpr (N != std::dynamic_extent)
        output.resize(input.size(), N);
      else
        output.resize(input.size(), input.size() > 0 ? input[0].size() : 0);
    }
    // 如果列是动态的，那么就要检查每一行的列数是否相同
    /*
    if constexpr (N == std::dynamic_extent)
      if ((input | std::views::transform([](const auto& row) { return row.size(); }) | std::ranges::unique).size() > 1)
        Logger::Guard().log<Logger::Level::Error>("The number of columns is not the same in each row.");
    */
    for (unsigned i = 0; i < M; i++)
      for (unsigned j = 0; j < N; j++)
        output(i, j) = input[i][j];
    return output;
  }
  template <Arithmetic T, int M, int N> inline std::conditional_t<N == 1, std::vector<T>, std::vector<std::vector<T>>>
    operator|(const Eigen::Matrix<T, M, N>& input, const detail_::FromEigenHelper&)
  {
    if constexpr (N == 1)
      return { input.data(), input.data() + input.size() };
    else
    {
      std::vector<std::vector<T>> output(input.rows());
      for (unsigned i = 0; i < input.rows(); i++)
        output[i] = { input.row(i).data(), input.row(i).data() + input.cols() };
      return output;
    }
  }
}
