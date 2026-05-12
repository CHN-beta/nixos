# pragma once
# include <zpp_bits.h>
# include <biu/serialize.hpp>

namespace biu
{
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
    auto begin = reinterpret_cast<const std::byte*>(serialized_data.data());
    auto end = begin + serialized_data.size();
    return deserialize<T>(std::vector<std::byte>{begin, end});
  }
}

namespace std
{
  template <typename Complex> constexpr auto serialize(auto & archive, Complex& complex)
    requires biu::SpecializationOf<std::remove_cvref_t<Complex>, std::complex>
  {
    if constexpr (std::integral<decltype(archive())>) return 2;
    else
    {
      using archive_type = std::remove_cvref_t<decltype(archive)>;
      std::array<typename Complex::value_type, 2> data;
      if constexpr (archive_type::kind() == zpp::bits::kind::out) data = {complex.real(), complex.imag()};
      zpp::bits::errc result;
      if (result = archive(data); result.code != std::errc{}) [[unlikely]] return result; 
      if constexpr (archive_type::kind() == zpp::bits::kind::in) complex = {data[0], data[1]};
      return result;
    }
  }
}
