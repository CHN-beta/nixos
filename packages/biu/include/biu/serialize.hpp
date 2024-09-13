# pragma once
# include <concurrencpp/concurrencpp.h>
# include <type_traits>
# include <fmt/format.h>
# include <magic_enum_all.hpp>
# include <biu/concepts.hpp>

namespace biu
{
  static_assert(sizeof(char) == sizeof(std::byte));
  template <typename Char = std::byte, typename T> requires (std::same_as<Char, std::byte>)
    std::vector<std::byte> serialize(const T& data);
  template <typename Char = std::byte, typename T> requires (std::same_as<Char, char>)
    std::string serialize(const T& data);
  template <typename T> T deserialize(const std::string& serialized_data);
  template <typename T> T deserialize(const std::vector<std::byte>& serialized_data);
}

namespace std
{
  // TODO: remove at clang19
  template <typename Complex> constexpr auto serialize(auto & archive, Complex& complex)
    requires biu::SpecializationOf<std::remove_cvref_t<Complex>, std::complex>;
}
