# include <biu.hpp>

int main()
{
  using namespace biu::literals;

  auto a = std::vector{1, 2, 3, 4, 5} | biu::eigen::toEigen<>;
  static_assert(std::same_as<decltype(a), Eigen::VectorXi>);
  auto b = std::array{1, 2, 3} | biu::eigen::toEigen<>;
  static_assert(std::same_as<decltype(b), Eigen::Vector3i>);
  auto c = std::vector{std::array{1, 2}, std::array{3, 4}, std::array{5, 6}}
    | biu::eigen::toEigen<>;
  static_assert(std::same_as<decltype(c),
    Eigen::Matrix<int, Eigen::Dynamic, 2, Eigen::RowMajor | Eigen::AutoAlign>>);
  auto d = std::array{std::array{1, 2}, std::array{3, 4}, std::array{5, 6}}
    | biu::eigen::toEigen<>;
  static_assert(std::same_as<decltype(d), Eigen::Matrix<int, 3, 2, Eigen::RowMajor | Eigen::AutoAlign>>);
  auto f = std::vector{1, 2, 3, 4, 5};
  assert(f == (f | biu::toEigen<> | biu::fromEigenVector<>));
  auto h = std::array{1, 2, 3};
  assert(h == (h | biu::toEigen<> | biu::fromEigenVector<>));
  auto g = std::vector
    {std::array{1, 2}, std::array{3, 4}, std::array{5, 6}};
  assert(g == (g | biu::toEigen<> | biu::fromEigenMatrix<>));

  auto e = biu::deserialize<decltype(c)>(biu::serialize(c));
  static_assert(std::same_as<decltype(e), decltype(c)>);
  assert(c == e);
}
