# pragma once
# include <highfive/H5File.hpp>

namespace biu
{
  namespace hdf5
  {
    struct PhonopyComplex { double r, i; };
    namespace detail_
    {
      HighFive::CompoundType create_phonopy_complex();
    }

    class Hdf5file
    {
      public:
        Hdf5file(std::string filename, bool truncate = false);
        template <typename T> Hdf5file& read(std::string name, T& object);
        template <typename T> T read(std::string name);
        template <typename T> Hdf5file& write(std::string name, const T& object);
        HighFive::File File;
    };
  }
  using hdf5::Hdf5file, hdf5::PhonopyComplex;
}

HIGHFIVE_REGISTER_TYPE(biu::hdf5::PhonopyComplex, biu::hdf5::detail_::create_phonopy_complex)
