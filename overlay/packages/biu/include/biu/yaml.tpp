# pragma once
# include <biu/yaml.hpp>
# include <biu/concepts.hpp>
# include <biu/format.hpp>
# ifdef __linux__
#   include <biu/eigen.hpp>
# endif
# include <boost/pfr.hpp>
# include <boost/pfr/core_name.hpp>
# include <nameof.hpp>
# include <magic_enum/magic_enum.hpp>
# include <range/v3/all.hpp>

namespace YAML
{
# ifdef __linux__
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
# endif
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
  template <biu::SpecializationOf<std::unique_ptr> Ptr> Node convert<Ptr>::encode(const Ptr& ptr)
  {
    if (ptr) return convert<typename Ptr::element_type>::encode(*ptr);
    else return YAML::Node{};
  }
  template <biu::SpecializationOf<std::unique_ptr> Ptr> bool convert<Ptr>::decode
    (const Node& node, Ptr& ptr)
  {
    if (!node.IsDefined() || node.IsNull()) ptr = nullptr;
    else
    {
      auto* value = new typename Ptr::element_type;
      if (!convert<typename Ptr::element_type>::decode(node, *value)) return false;
      ptr.reset(value);
    }
    return true;
  }
  template <biu::Set Set> Node convert<Set>::encode(const Set& set)
    { return convert<std::vector<typename Set::value_type>>::encode(set | ranges::to_vector); }
  template <biu::Set Set> bool convert<Set>::decode(const Node& node, Set& set)
  {
    std::vector<typename Set::value_type> vec;
    if (!convert<std::vector<typename Set::value_type>>::decode(node, vec)) return false;
    set = vec | ranges::to<Set>;
    return true;
  }
  template <biu::Enumerable Enum> Node convert<Enum>::encode(const Enum& e)
    { return convert<std::string_view>::encode(nameof::nameof_enum(e)); }
  template <biu::Enumerable Enum> bool convert<Enum>::decode(const Node& node, Enum& e)
  {
    std::string name;
    if (!convert<std::string>::decode(node, name)) return false;
    auto optional_value = magic_enum::enum_cast<Enum>(name);
    if (!optional_value) return false;
    else { e = *optional_value; return true; }
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
