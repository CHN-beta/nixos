# pragma once
# include <biu/hdf5.hpp>

namespace biu::hdf5
{
  template <typename T> Hdf5file& Hdf5file::read(std::string name, T& object)
    { object = File_.getDataSet(name).read<std::remove_cvref_t<decltype(object)>>(); return *this; }
  template <typename T> T Hdf5file::read(std::string name)
    { std::remove_cvref_t<T> object; read(name, object); return object; }
  template <typename T> Hdf5file& Hdf5file::write(std::string name, const T& object)
    { File_.createDataSet(name, object); return *this; }
}
