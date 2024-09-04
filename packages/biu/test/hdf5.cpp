# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  biu::Hdf5file("test.h5").write("test", 42);
}
