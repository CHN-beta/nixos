# pragma once
# include <biu/eigen.hpp>
# include <biu/common.hpp>
# include <range/v3/view.hpp>
# include <zpp_bits.h>

namespace biu::eigen
{
  template <std::size_t ToSize, typename Container> auto detail_::deduce_eigen_size()
  {
    if constexpr (ToSize == detail_::dynamicSize) return Empty{};
    else if constexpr (ToSize == detail_::unspecifiedSize)
      if constexpr (SpecializationOfArray<Container>) return Container::size();
      else return Empty{};
    else
      if constexpr (SpecializationOfArray<Container>)
        if (Container::size() == ToSize) return ToSize;
        else throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
      else return ToSize;
  }
  template <Arithmetic T, detail_::StandardContainer<T> From, std::size_t ToSize> auto operator|
    (const From& from, const detail_::ToEigenHelper<ToSize, detail_::unspecifiedSize>&)
  {
    // dynamic size
    if (detail_::deduce_eigen_size<ToSize, From>() == Empty{})
      return Eigen::Vector<T, Eigen::Dynamic>(from.data(), from.size());
    // fixed size
    else
      // from vector, vector.size() == ToSize
      if (SpecializationOf<From, std::vector, T> && from.size() == ToSize)
        return Eigen::Vector<T, ToSize>(from.data());
      else
        throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
  }
  template
  <
    Arithmetic T, detail_::StandardContainer<T> FromPerRow, detail_::StandardContainer<FromPerRow> From,
    std::size_t ToRow, std::size_t ToCol
  >
    auto operator|(const From& from, const detail_::ToEigenHelper<ToRow, ToCol>&)
  {
    auto nRow = detail_::deduce_eigen_size<ToRow, From>();
    auto nCol = detail_::deduce_eigen_size<ToCol, FromPerRow>();

    // ensure all rows have the same size
    std::vector<std::size_t> size_in_each_row;
    // each row is a std::array, they must have the same size
    if constexpr (!SpecializationOf<FromPerRow, std::vector, T>)
      size_in_each_row.push_back(FromPerRow::size());
    else
      size_in_each_row = from
        | ranges::views::transform([](const auto& row) { return row.size(); })
        | ranges::views::unique
        | ranges::to<std::vector<std::size_t>>;
    if (size_in_each_row.size() > 1)
      throw std::invalid_argument("The sizes of the rows of the input container are not the same");
    else if (size_in_each_row.empty()) size_in_each_row.push_back(0);

    // ensure specified size is consistent with the input
    if (nRow != Empty{} && SpecializationOf<From, std::vector> && from.size() != nRow)
      throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");
    if (nCol != Empty{} && size_in_each_row[0] != nCol)
      throw std::invalid_argument("The size of the destination Eigen container mismatches the input container");

    // copy all data into a single vector
    auto data = from | ranges::views::join | ranges::to<std::vector<T>>;

    // dynamic row and dynamic col
    if constexpr (nRow == Empty{} && nCol == Empty{})
      return Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor | Eigen::AutoAlign>
        (data.data(), from.size(), size_in_each_row[0]);
    // fixed row and dynamic col
    else if constexpr (nRow != Empty{} && nCol == Empty{})
      return Eigen::Matrix<T, nRow, Eigen::Dynamic, Eigen::RowMajor | Eigen::AutoAlign>
        (data.data(), size_in_each_row[0]);
    // dynamic row and fixed col
    else if constexpr (nRow == Empty{} && nCol != Empty{})
      return Eigen::Matrix<T, Eigen::Dynamic, nCol, Eigen::RowMajor | Eigen::AutoAlign>
        (data.data(), from.size());
    // fixed row and fixed col
    else
      return Eigen::Matrix<T, ToRow, ToCol, Eigen::RowMajor | Eigen::AutoAlign>
        (data.data());
  }
}
template <typename Matrix> constexpr auto Eigen::serialize(auto & archive, Matrix& matrix)
  requires biu::EigenMatrix<std::remove_cvref_t<Matrix>>
  {
    auto nRow = matrix.rows(), nCol = matrix.cols();
    zpp::bits::errc result;
    if (result.code == std::errc{} && Matrix::CompileTimeTraits::RowsAtCompileTime == Eigen::Dynamic)
      result = archive(nRow);
    if (result.code == std::errc{} && Matrix::CompileTimeTraits::ColsAtCompileTime == Eigen::Dynamic)
      result = archive(nCol);
    if (archive.kind() == zpp::bits::kind::in)
      matrix.resize(nRow, nCol);
    if (result.code == std::errc{})
      result = archive(matrix.data(), matrix.size());
    return result;
  }
