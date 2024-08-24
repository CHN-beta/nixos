# include <biu.hpp>

namespace biu::hdf5
{
  Hdf5file::Hdf5file(std::string filename, bool readonly)
  : File_
  (
    filename, 
    readonly ? HighFive::File::ReadOnly
      : HighFive::File::ReadWrite | HighFive::File::Create | HighFive::File::Truncate
  )
  {}
  HighFive::CompoundType detail_::create_phonopy_complex()
    { return {{ "r", HighFive::AtomicType<double>{}}, {"i", HighFive::AtomicType<double>{}}}; }
}
