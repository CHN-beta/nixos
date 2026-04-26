# pragma once
# include <biu/atomic.tpp>
# include <biu/called_by.hpp>
# include <biu/common.tpp>
# include <biu/concepts.tpp>
# include <biu/string.tpp>
# include <biu/format.tpp>
# ifdef __linux__
#   include <biu/eigen.tpp>
#   include <biu/hdf5.tpp>
#   include <biu/process.tpp>
# endif
# ifndef BIU_INTERNAL
// while building the library, the logger should not be included, to ensure inline members are not compiled
#   include <biu/logger.tpp>
# endif
# include <biu/smartref.tpp>
# include <biu/fft.tpp>
# include <biu/yaml.tpp>
# include <biu/serialize.tpp>
# include <range/v3/all.hpp>
