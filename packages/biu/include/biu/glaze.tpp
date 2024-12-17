# pragma once
# include <biu/glaze.hpp>

template <biu::EigenMatrix Matrix> template <auto Opts> void
  glz::detail::from<glz::JSON, Matrix>::op(Matrix& matrix, auto&&... args)
{
  decltype(matrix | biu::fromEigen) std_matrix;
  read<JSON>::op<Opts>(std_matrix, args...);
  matrix = std_matrix | biu::toEigen<>;
}
template <biu::EigenMatrix Matrix> template <auto Opts> void
  glz::detail::to<glz::JSON, Matrix>::op(Matrix& matrix, auto&&... args) noexcept
{
  write<JSON>::op<Opts>(matrix | biu::fromEigen, args...);
}
