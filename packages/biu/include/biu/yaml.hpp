# pragma once
# include <yaml-cpp/yaml.h>
# ifdef __linux__
#   include <biu/eigen.hpp>
# endif

namespace biu
{
  struct YamlParsable {};
}

namespace YAML
{
# ifdef __linux__
  template <biu::EigenMatrix Matrix> struct convert<Matrix>
  {
    static Node encode(const Matrix&);
    static bool decode(const Node& node, Matrix&);
  };
# endif
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
  template <biu::SpecializationOf<std::unique_ptr> Ptr> struct convert<Ptr>
  {
    static Node encode(const Ptr&);
    static bool decode(const Node& node, Ptr&);
  };
  template <biu::Set Set> struct convert<Set>
  {
    static Node encode(const Set&);
    static bool decode(const Node& node, Set&);
  };
  template <biu::Enumerable Enum> struct convert<Enum>
  {
    static Node encode(const Enum&);
    static bool decode(const Node& node, Enum&);
  };
  template <typename T> struct convert
  {
    static Node encode(const T&);
    static bool decode(const Node& node, T&);
  };
}
