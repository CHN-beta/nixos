# include <hpcstat/common.hpp>
# include <hpcstat/sql.hpp>
# include <hpcstat/disk.hpp>

namespace hpcstat
{
  long now()
  {
    return std::chrono::duration_cast<std::chrono::seconds>
      (std::chrono::system_clock::now().time_since_epoch()).count();
  }
  std::string serialize(auto data)
  {
    auto [serialized_data_byte, out] = zpp::bits::data_out();
    out(data).or_throw();
    static_assert(sizeof(char) == sizeof(std::byte));
    return { reinterpret_cast<char*>(serialized_data_byte.data()), serialized_data_byte.size() };
  }
  template std::string serialize(sql::LoginData);
  template std::string serialize(sql::SubmitJobData);
  template std::string serialize(sql::FinishJobData);
  template <typename T> T deserialize(std::string serialized_data)
  {
    auto [serialized_data_byte, in] = zpp::bits::data_in();
    static_assert(sizeof(char) == sizeof(std::byte));
    serialized_data_byte = std::vector<std::byte>(reinterpret_cast<const std::byte*>(serialized_data.c_str()),
      reinterpret_cast<const std::byte*>(serialized_data.c_str()) + serialized_data.length());
    T data;
    in(data).or_throw();
    return data;
  }
}
