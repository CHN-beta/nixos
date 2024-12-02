# pragma once
# include <biu/eigen.hpp>
# include <glaze/glaze.hpp>

namespace glz::detail
{
  template <biu::EigenMatrix Matrix> struct from<JSON, Matrix>
  {
    template <auto Opts> static void op(Matrix& matrix, auto&&... args);
  };

  template <biu::EigenMatrix Matrix> struct to<JSON, Matrix>
  {
    template <auto Opts> static void op(Matrix& matrix, auto&&... args) noexcept;
  };
}

template <typename Scalar, int Rows, int Cols, int Options, int MaxRows, int MaxCols>
struct glz::meta<Eigen::Matrix<Scalar, Rows, Cols, Options, MaxRows, MaxCols>>
{
   static constexpr std::string_view name = join_v
   <
    chars<"Eigen::Matrix<">, name_v<Scalar>, chars<",">,
    chars<num_to_string<Rows>::value>, chars<",">,
    chars<num_to_string<Cols>::value>, chars<",">,
    chars<num_to_string<Options>::value>, chars<",">,
    chars<num_to_string<MaxRows>::value>, chars<",">,
    chars<num_to_string<MaxCols>::value>,
    chars<">">
  >;
};
