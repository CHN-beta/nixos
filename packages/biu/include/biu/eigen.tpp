# pragma once
# include <biu/eigen.hpp>
# include <biu/common.hpp>
# include <range/v3/view.hpp>
# include <zpp_bits.h>

namespace biu::eigen
{
  template <std::size_t ToSize, typename Container> constexpr auto detail_::deduce_eigen_size()
  {
    if constexpr (ToSize == detail_::dynamicSize) return Empty{};
    else if constexpr (ToSize == detail_::unspecifiedSize)
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
    typename Matrix::Index nRow, nCol;
    std::vector<typename Matrix::Scalar> data;
    if constexpr (archive.kind() == zpp::bits::kind::out)
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
    if constexpr (archive.kind() == zpp::bits::kind::in)
      matrix = Eigen::Map<const Matrix>(data.data(), nRow, nCol);
    return result;
  }
}
