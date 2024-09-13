# include <biu.hpp>

int main()
{
  struct student
  {
    int number;
    std::string name;
    std::vector<std::optional<double>> grade;
    using serialize = zpp::bits::members<3>;
    auto operator<=>(const student&) const = default;
  };
  student bob{ 123, "Bob", { 3.5, std::nullopt, 4.0 } };
  auto serialized_bob = biu::serialize(bob);
  auto bob2 = biu::deserialize<student>(serialized_bob);
  assert(bob == bob2);
  struct A
  {
    int x;
    std::string y;
    std::complex<double> z;
  };
  A a{ 123, "abc", 3i };
  auto b = biu::deserialize<A>(biu::serialize(a));
  assert(a.x == b.x);
  assert(a.y == b.y);
  assert(a.z == b.z);
}
