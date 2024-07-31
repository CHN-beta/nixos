# pragma once
# include <boost/functional/hash.hpp>
# include <zpp_bits.h>
# include <biu/common.hpp>

namespace biu::common
{
  void unused(auto&&...) {}
  std::size_t hash(auto&&... objs)
  {
    std::size_t result = 0;
    (boost::hash_combine(result, objs), ...);
    return result;
  }

  template <typename String> constexpr bool CaseInsensitiveStringLessComparator::operator()
    (const String& s1, const String& s2) const
  {
    return std::lexicographical_compare
    (
      s1.begin(), s1.end(), s2.begin(), s2.end(),
      [](char c1, char c2){return std::tolower(c1) < std::tolower(c2);}
    );
  }

  template <typename Char, typename T> requires (std::same_as<Char, std::byte>)
    std::vector<std::byte> serialize(const T& data)
  {
    auto [serialized_data, out] = zpp::bits::data_out();
    out(data).or_throw();
    return serialized_data;
  }
  template <typename Char, typename T> requires (std::same_as<Char, char>) std::string serialize(const T& data)
  {
    auto serialized_data = serialize<std::byte>(data);
    return {reinterpret_cast<const char*>(serialized_data.data()), serialized_data.size()};
  }
  template <typename T> T deserialize(const std::vector<std::byte>& serialized_data)
  {
    auto in = zpp::bits::in(serialized_data);
    T data;
    in(data).or_throw();
    return data;
  }
  template <typename T> T deserialize(const std::string& serialized_data)
  {
    auto begin = reinterpret_cast<const std::byte*>(serialized_data.data()), end = begin + serialized_data.size();
    return deserialize<T>(std::vector<std::byte>{begin, end});
  }
}
