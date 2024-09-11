# pragma once
# include <utility>
# include <biu/eigen.hpp>
# include <biu/common.hpp>
# include <range/v3/view.hpp>
# include <zpp_bits.h>

namespace biu::eigen
{
  template <std::size_t ToSize, typename Container> consteval auto detail_::deduce_eigen_size()
  {
    if constexpr (ToSize == dynamicSize) return Empty{};
    else if constexpr (ToSize == unspecifiedSize)
      if constexpr (SpecializationOfArray<Container>) return Container{}.size();
      else return Empty{};
    else
      if constexpr (SpecializationOfArray<Container>)
        if (Container{}.size() == ToSize) return ToSize;
        else throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
      else return ToSize;
  }

  template <typename From, std::size_t ToSize> auto detail_::operator|
    (const From& from, const detail_::ToEigenHelper<ToSize, detail_::unspecifiedSize>&)
    requires (detail_::StandardContainer<From, typename From::value_type> && Arithmetic<typename From::value_type>)
  {
    using Scalar = typename From::value_type;
    // dynamic size
    if constexpr (detail_::deduce_eigen_size<ToSize, From>() == Empty{})
    {
      using Vector = Eigen::Vector<Scalar, Eigen::Dynamic>;
      return Vector(Eigen::Map<const Vector>(from.data(), from.size()));
    }
    // fixed size
    else
      // from std::array, or from std::vector and vector.size() == ToSize
      if (!SpecializationOf<From, std::vector, Scalar> || from.size() == ToSize)
      {
        using Vector = Eigen::Vector<Scalar, static_cast<int>(detail_::deduce_eigen_size<ToSize, From>())>;
        return Vector(Eigen::Map<const Vector>(from.data()));
      }
      else
        throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
  }
  template <typename From, std::size_t ToRow, std::size_t ToCol> auto detail_::operator|
    (const From& from, const detail_::ToEigenHelper<ToRow, ToCol>&)
    requires
    (
      detail_::StandardContainer<From, typename From::value_type>
      && detail_::StandardContainer<typename From::value_type, typename From::value_type::value_type>
      && Arithmetic<typename From::value_type::value_type>
    )
  {
    constexpr auto nRow = detail_::deduce_eigen_size<ToRow, From>();
    constexpr auto nCol = detail_::deduce_eigen_size<ToCol, typename From::value_type>();
    using FromPerRow = typename From::value_type;
    using Scalar = typename FromPerRow::value_type;

    // ensure all rows have the same size
    std::vector<std::size_t> size_in_each_row;
    // each row is a std::array, they must have the same size
    if constexpr (!SpecializationOf<FromPerRow, std::vector, Scalar>)
      size_in_each_row.push_back(FromPerRow{}.size());
    else
      size_in_each_row = from
        | ranges::views::transform([](const auto& row) { return row.size(); })
        | ranges::views::unique
        | ranges::to<std::vector<std::size_t>>;
    if (size_in_each_row.size() > 1)
      throw std::invalid_argument("The sizes of the rows of the input container are not the same");
    else if (size_in_each_row.empty()) size_in_each_row.push_back(0);

    // ensure specified size is consistent with the input
    if constexpr (nRow != Empty{})
      if (SpecializationOf<From, std::vector> && from.size() != nRow)
        throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
    if constexpr (nCol != Empty{})
      if (size_in_each_row[0] != nCol)
        throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");

    // copy all data into a single vector
    auto data = from | ranges::views::join | ranges::to<std::vector<Scalar>>;

    // dynamic row and dynamic col
    if constexpr (nRow == Empty{} && nCol == Empty{})
    {
      using Matrix = Eigen::Matrix<Scalar, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor | Eigen::AutoAlign>;
      return Matrix(Eigen::Map<const Matrix>(data.data(), from.size(), size_in_each_row[0]));
    }
    // fixed row and dynamic col
    else if constexpr (nRow != Empty{} && nCol == Empty{})
    {
      using Matrix = Eigen::Matrix<Scalar, nRow, Eigen::Dynamic, Eigen::RowMajor | Eigen::AutoAlign>;
      return Matrix(Eigen::Map<const Matrix>(data.data(), nRow, size_in_each_row[0]));
    }
    // dynamic row and fixed col
    else if constexpr (nRow == Empty{} && nCol != Empty{})
    {
      using Matrix = Eigen::Matrix<Scalar, Eigen::Dynamic, nCol, Eigen::RowMajor | Eigen::AutoAlign>;
      return Matrix(Eigen::Map<const Matrix>(data.data(), from.size(), nCol));
    }
    // fixed row and fixed col
    else
    {
      using Matrix = Eigen::Matrix<Scalar, nRow, nCol, Eigen::RowMajor | Eigen::AutoAlign>;
      return Matrix(Eigen::Map<const Matrix>(data.data()));
    }
  }

  template <typename Vector, std::size_t ToSize> auto detail_::operator|
    (const Vector& vector, const detail_::FromEigenVectorHelper<ToSize>&)
  {
    // 尽量在编译时获得大小并检查大小是否匹配，第一个返回值为确定的大小，第二个返回值为用于在运行时检查大小的函数
    auto get_size = []<std::size_t to_size>(this auto&& self) consteval
    {
      // 如果没有指定
      if constexpr (to_size == unspecifiedSize)
        // 如果两个维度都是动态的，那么作为动态大小处理
        if constexpr
        (
          Vector::CompileTimeTraits::RowsAtCompileTime == Eigen::Dynamic
            && Vector::CompileTimeTraits::ColsAtCompileTime == Eigen::Dynamic
        )
          return std::make_pair
            (dynamicSize, [](const Vector& vector) { return vector.nrows() <= 1 && vector.ncols() <= 1; });
        // 如果两个维度都是固定的
        else if constexpr
        (
          Vector::CompileTimeTraits::RowsAtCompileTime != Eigen::Dynamic
            && Vector::CompileTimeTraits::ColsAtCompileTime != Eigen::Dynamic
        )
          // 如果两个维度都超过了 1
          if constexpr
            (Vector::CompileTimeTraits::RowsAtCompileTime > 1 && Vector::CompileTimeTraits::ColsAtCompileTime > 1)
            throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
          // 否则返回两个维度的乘积
          else return std::make_pair
          (
            Vector::CompileTimeTraits::RowsAtCompileTime * Vector::CompileTimeTraits::ColsAtCompileTime,
            // consteval need c++23 P2280
            [](const Vector&) { return true; }
          );
        // 如果固定的那个维度等于 1，那么为动态大小（大小取决于另外一个没有固定的维度）
        // 否则，大小等于这个维度，另一个维度是否为 1 留作之后检查
        else if constexpr (Vector::CompileTimeTraits::RowsAtCompileTime != Eigen::Dynamic)
          if constexpr (Vector::CompileTimeTraits::RowsAtCompileTime == 1)
            // consteval need c++23 P2280
            return std::make_pair(dynamicSize, [](const Vector&) { return true; });
          else
            return std::make_pair
            (
              Vector::CompileTimeTraits::RowsAtCompileTime,
              [](const Vector& vector) { return vector.ncols() <= 1; }
            );
        else if constexpr (Vector::CompileTimeTraits::ColsAtCompileTime != Eigen::Dynamic)
          if constexpr (Vector::CompileTimeTraits::ColsAtCompileTime == 1)
            // consteval need c++23 P2280
            return std::make_pair(dynamicSize, [](const Vector&) { return true; });
          else
            return std::make_pair
            (
              Vector::CompileTimeTraits::ColsAtCompileTime,
              [](const Vector& vector) { return vector.nrows() <= 1; }
            );
        else
          std::unreachable();
      // 如果指定了为动态：同样按照上述检查，但返回动态大小
      else if constexpr (to_size == dynamicSize)
        return std::make_pair(dynamicSize, self->template operator()<unspecifiedSize>().second);
      // 如果指定了大小：按照上述检查，如果判断为静态大小且大小不一致则报错，如果判断为动态大小则额外判断大小
      else
      {
        auto result = self->template operator()<unspecifiedSize>();
        if constexpr (result.first != dynamicSize)
          if constexpr (result.first != to_size)
            throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
          else
            return result;
        else
          return std::make_pair
          (
            to_size,
            [size = to_size](const Vector& vector) { return vector.size() == size; }
          );
      }
    };
    // decomposition declarations can't be constexpr
    constexpr auto size = get_size.template operator()<ToSize>();
# ifndef NDEBUG
    if (!size.second(vector))
      throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
# endif
    if constexpr (size.first == dynamicSize)
      return std::vector<typename Vector::Scalar>(vector.data(), vector.data() + vector.size());
    else
    {
      auto to_array = []<std::size_t N, std::size_t... I>(const auto& vector, std::index_sequence<I...>)
        { return std::array<typename Vector::Scalar, N>{vector[I]...}; };
      return to_array.template operator()<size.first>(vector.data(), std::make_index_sequence<size.first>());
    }
  }

  template <typename Matrix, std::size_t ToRow, std::size_t ToCol> auto detail_::operator|
    (const Matrix& matrix, const detail_::FromEigenMatrixHelper<ToRow, ToCol>&)
  {
    auto get_size = [] consteval
    {
      auto get_one_size = []<std::size_t to_size, int eigen_size> consteval
      {
        // 如果没有指定
        if constexpr (to_size == unspecifiedSize)
          // 如果原大小是动态的，那么作为动态大小处理
          if constexpr (eigen_size == Eigen::Dynamic)
            return std::make_pair(dynamicSize, [](int) { return true; });
          // 否则返回原大小
          else return std::make_pair(eigen_size, [](int) { return true; });
        // 如果指定为动态大小：直接返回动态大小
        else if constexpr (to_size == dynamicSize)
          return std::make_pair(dynamicSize, [](int) { return true; });
        // 如果指定了大小：如果原大小是动态的则返回指定的大小，并在稍后检查；否则现在检查并返回
        else
          if constexpr (eigen_size == Eigen::Dynamic)
            return std::make_pair(to_size, [](int original_size) { return to_size == original_size; });
          else
            if constexpr (to_size == eigen_size)
              return std::make_pair(to_size, [](int) { return true; });
            else
              throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
      };
      constexpr auto row = get_one_size.template operator()<ToRow, Matrix::CompileTimeTraits::RowsAtCompileTime>();
      constexpr auto col = get_one_size.template operator()<ToCol, Matrix::CompileTimeTraits::ColsAtCompileTime>();
      return std::make_pair
      (
        std::make_pair(row.first, col.first),
        [row_check = row.second, col_check = col.second](const Matrix& matrix)
          { return row_check(matrix.rows()) && col_check(matrix.cols()); }
      );
    };

    // decomposition declarations can't be constexpr
    constexpr auto size = get_size();
# ifndef NDEBUG
    if (!size.second(matrix))
      throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
# endif

    using container_per_row = std::conditional_t<size.first.second == dynamicSize,
      std::vector<typename Matrix::Scalar>, std::array<typename Matrix::Scalar, size.first.second>>;
    using container = std::conditional_t<size.first.first == dynamicSize,
      std::vector<container_per_row>, std::array<container_per_row, size.first.first>>;
    container result;
    if constexpr (size.first.first == dynamicSize) result.resize(matrix.rows());
    if constexpr (size.first.second == dynamicSize) for (auto& row : result) row.resize(matrix.cols());
    for (int i = 0; i < matrix.rows(); i++)
    {
      using RowVector = Eigen::RowVector
      <
        typename Matrix::Scalar,
        size.first.second == dynamicSize ? Eigen::Dynamic
          : static_cast<decltype(Eigen::Dynamic)>(size.first.second)
      >;
      Eigen::Map<RowVector>(result[i].data(), 1, matrix.cols()) = matrix.row(i);
    }
    return result;
  }
  template <typename Matrix> auto detail_::operator|(const Matrix& matrix, const detail_::FromEigenHelper&)
  {
    constexpr auto
      ncols = Matrix::CompileTimeTraits::ColsAtCompileTime, nrows = Matrix::CompileTimeTraits::RowsAtCompileTime;
    if constexpr ((ncols <= 1 && ncols != Eigen::Dynamic) || (nrows <= 1 && nrows != Eigen::Dynamic))
      return matrix | fromEigenVector<>;
    else
      return matrix | fromEigenMatrix<>;
  }

}
template <typename Matrix> constexpr auto Eigen::serialize(auto & archive, Matrix& matrix)
  requires biu::EigenMatrix<std::remove_cvref_t<Matrix>>
{
  // this function will be called twice, first to get how many members to archive, then to archive the members
  // first call
  if constexpr (std::integral<decltype(archive())>)
    return 1 + (Matrix::CompileTimeTraits::RowsAtCompileTime == Eigen::Dynamic)
      + (Matrix::CompileTimeTraits::ColsAtCompileTime == Eigen::Dynamic);
  // second call
  else
  {
    using archive_type = std::remove_cvref_t<decltype(archive)>;
    typename Matrix::Index nRow, nCol;
    std::vector<typename Matrix::Scalar> data;
    if constexpr (archive_type::kind() == zpp::bits::kind::out)
      { nRow = matrix.rows(); nCol = matrix.cols(); data = std::vector(matrix.data(), matrix.data() + matrix.size()); }
    zpp::bits::errc result;
    if constexpr (Matrix::CompileTimeTraits::RowsAtCompileTime == Eigen::Dynamic)
      { if (result = archive(nRow); result.code != std::errc{}) [[unlikely]] return result; }
    else nRow = Matrix::CompileTimeTraits::RowsAtCompileTime;
    if constexpr (Matrix::CompileTimeTraits::ColsAtCompileTime == Eigen::Dynamic)
      { if (result = archive(nCol); result.code != std::errc{}) [[unlikely]] return result; }
    else nCol = Matrix::CompileTimeTraits::ColsAtCompileTime;
    result = archive(data);
    if (result.code != std::errc{}) [[unlikely]] return result;
    if constexpr (archive_type::kind() == zpp::bits::kind::in)
      matrix = Eigen::Map<const Matrix>(data.data(), nRow, nCol);
    return result;
  }
}
