# pragma once
# include <biu/eigen.hpp>
// TODO: fix biu::logger
// # include <biu/logger.hpp>
# include <range/v3/view.hpp>

namespace biu
{
  namespace detail_::eigen
  {
    template <template <int N> typename Callback, std::size_t ToSize> auto deduce_eigen_size(auto&& from)
    {
      if constexpr (ToSize == dynamicSize)
        return Callback<Eigen::Dynamic>()(from.data(), from.size());
      else if constexpr (ToSize == unspecifiedSize)
        if constexpr (SpecializationOfArray<decltype(from)>)
          return Callback<from.size()>()(from.data());
        else
          return Callback<Eigen::Dynamic>()(from.data(), from.size());
      else
        if (from.size() != ToSize)
          // TODO: use biu::logger
          throw std::invalid_argument("biu::toEigen: size mismatch");
        else
          return Callback<ToSize>()(from.data());
    }
    // TODO: implement 2D case
  }
}
