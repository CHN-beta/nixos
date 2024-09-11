# pragma once
# include <yaml-cpp/yaml.h>
# include <biu/eigen.hpp>

namespace biu
{
  struct YamlParsable {};
}

namespace YAML
{
  template <biu::EigenMatrix Matrix> struct convert<Matrix>
  {
    static Node encode(const Matrix&);
    static bool decode(const Node& node, Matrix&);
  };
  template <biu::SpecializationOf<std::complex> Complex> struct convert<Complex>
  {
    static Node encode(const Complex&);
    static bool decode(const Node& node, Complex&);
  };
  template <biu::SpecializationOf<std::optional> Optional> struct convert<Optional>
  {
    static Node encode(const Optional&);
    static bool decode(const Node& node, Optional&);
  };
  template <typename T> struct convert
  {
    static Node encode(const T&);
    static bool decode(const Node& node, T&);
  };
}
