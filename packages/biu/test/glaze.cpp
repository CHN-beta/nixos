// # include <biu.hpp>
# include <glaze/glaze.hpp>
# include <Eigen/Dense>
# include <glaze/ext/eigen.hpp>

struct aaa
{
  int a = 1;
  double b = 2;
  std::string c = "3";
  Eigen::Matrix3d d = Eigen::Matrix3d::Identity();
  bool operator==(const aaa&) const = default;
} bbb;

int main()
{
  auto result = glz::write_json(bbb.d).value();
  // auto result2 = glz::read_json<aaa>(result).value();
  // assert(bbb == result2);
}
