# pragma once
# include <biu/yaml.hpp>
# include <biu/concepts.hpp>
# include <biu/format.hpp>
# include <biu/eigen.hpp>
# include <boost/pfr.hpp>
# include <boost/pfr/core_name.hpp>

namespace YAML
{
  template <biu::EigenMatrix Matrix> Node convert<Matrix>::encode(const Matrix& matrix)
  {
    auto std_matrix = matrix | biu::fromEigen;
    return convert<decltype(std_matrix)>::encode(std_matrix);
  }
  template <biu::EigenMatrix Matrix> bool convert<Matrix>::decode(const Node& node, Matrix& matrix)
  {
    using std_matrix = decltype(matrix | biu::fromEigen);
    std_matrix value;
    if (!convert<std_matrix>::decode(node, value)) return false;
    matrix = value | biu::toEigen<>;
    return true;
  }
  template <biu::SpecializationOf<std::complex> Complex> Node convert<Complex>::encode(const Complex& complex)
  {
    return convert<std::array<typename Complex::value_type, 2>>::encode({ complex.real(), complex.imag() });
  }
  template <biu::SpecializationOf<std::complex> Complex> bool convert<Complex>::decode
    (const Node& node, Complex& complex)
  {
    std::array<typename Complex::value_type, 2> arr;
    if (!convert<std::array<typename Complex::value_type, 2>>::decode(node, arr)) return false;
    complex = Complex{ arr[0], arr[1] };
    return true;
  }
  template <biu::SpecializationOf<std::optional> Optional> Node convert<Optional>::encode(const Optional& optional)
  {
    if (optional) return convert<typename Optional::value_type>::encode(*optional);
    else return YAML::Node{};
  }
  template <biu::SpecializationOf<std::optional> Optional> bool convert<Optional>::decode
    (const Node& node, Optional& optional)
  {
    if (!node.IsDefined() || node.IsNull()) optional = std::nullopt;
    else
    {
      typename Optional::value_type value;
      if (!convert<typename Optional::value_type>::decode(node, value)) return false;
      optional = value;
    }
    return true;
  }
  template <typename T> Node convert<T>::encode(const T& t)
  {
    YAML::Node node;
    boost::pfr::for_each_field(t, [&](const auto& field, auto index)
    {
      using type = std::remove_cvref_t<decltype(field)>;
      auto name = boost::pfr::get_name<decltype(index)::value, T>();
      node[name] = convert<type>::encode(field);
    });
    return node;
  }
  template <typename T> bool convert<T>::decode(const Node& node, T& t)
  {
    bool result = true;
    boost::pfr::for_each_field(t, [&](auto& field, auto index)
    {
      using type = std::remove_cvref_t<decltype(field)>;
      auto name = boost::pfr::get_name<decltype(index)::value, T>();
      result = result && convert<type>::decode(node[name], field);
    });
    return result;
  }
}
