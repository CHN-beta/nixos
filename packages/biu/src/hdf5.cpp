# include <biu.hpp>

namespace biu::hdf5
{
  Hdf5file::Hdf5file(std::string filename, bool truncate)
  : File_
  (
    filename, 
    ({ using _ = HighFive::File; truncate ? _::ReadWrite | _::Create | _::Truncate : _::ReadOnly; })
  )
  {}
  HighFive::CompoundType detail_::create_phonopy_complex()
    { return {{ "r", HighFive::AtomicType<double>{}}, {"i", HighFive::AtomicType<double>{}}}; }
}
