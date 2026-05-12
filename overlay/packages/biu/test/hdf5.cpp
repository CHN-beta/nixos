# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  // create file and write data
  biu::Hdf5file("test.h5", true).write("test", 42);
  // read data
  assert(biu::Hdf5file("test.h5").read<int>("test") == 42);
  // trucate data
  biu::Hdf5file("test.h5", true).write("test", std::vector{1, 2, 3});
}
