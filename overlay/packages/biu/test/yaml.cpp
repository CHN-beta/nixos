# include <biu.hpp>
# include <yaml-cpp/yaml.h>

int main()
{
  using namespace biu::literals;
  std::string data = R"(
a: [ 1, 2, 3 ]
b: [ [ 1, 2, 3 ], [ 4, 5, 6 ], [ 7, 8, 9 ] ]
c: [ 1, 2 ]
d: null
)";
  auto node = YAML::Load(data);
# ifdef __linux__
  auto a = node["a"].as<Eigen::Vector3i>();
  auto a2 = node["a"].as<Eigen::VectorXi>();
  auto b = node["b"].as<Eigen::Matrix3i>();
  auto b2 = node["b"].as<Eigen::MatrixXi>();
  assert(a == a2);
  assert(a(0) == 1);
  assert(a(1) == 2);
  assert(a(2) == 3);
  assert(b == b2);
# endif
  auto c = node["c"].as<std::complex<double>>();
  assert(c == 1. + 2i);
  auto d = node["d"].as<std::optional<int>>();
  auto c3 = node["c"].as<std::optional<std::complex<double>>>();
  assert(d == std::nullopt);
  assert(c3 == 1. + 2i);
  struct A
  {
# ifdef __linux__
    Eigen::Vector3i a;
    Eigen::Matrix3i b;
    std::unique_ptr<Eigen::Matrix3d> d;
# endif
    std::complex<double> c;
  };
  auto a3 = node.as<A>();
# ifdef __linux__
  assert(a3.a == a);
  assert(a3.b == b);
  assert(a3.d == nullptr);
# endif
  assert(a3.c == c);
  auto e = node["c"].as<std::set<int>>();
  assert((e == std::set<int>{1, 2}));
  node["c"] = e;
  std::string data2 = R"(
a: AAA
)";
  enum class E { AAA, BBB, CCC };
  auto f = YAML::Load(data2)["a"].as<E>();
}
