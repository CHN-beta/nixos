# include <future>
# include <utility>
# include <cstdio>
# define BIU_INTERNAL
# include <biu.hpp>

namespace biu
{
  std::regex literals::operator""_re(const char* str, std::size_t len) { return std::regex{str, len}; }
  namespace common
  {
    void block_forever() { std::promise<void>().get_future().wait(); std::unreachable(); }
    bool is_interactive() { return isatty(fileno(stdin)); }
    std::optional<std::string> env(std::string name)
    {
      if (auto value = std::getenv(name.c_str()); !value) return std::nullopt;
      else return value;
    }

    template<> std::vector<std::byte> read<std::byte>(const std::filesystem::path& path)
    {
      auto length = std::filesystem::file_size(path);
      std::vector<std::byte> buffer(length);
      std::ifstream in(path, std::ios_base::binary);
      in.read(reinterpret_cast<char*>(buffer.data()), length);
      return buffer;
    }
    template<> std::string read<char>(const std::filesystem::path& path)
    {
      auto buffer = read<std::byte>(path);
      return std::string{reinterpret_cast<char*>(buffer.data()), buffer.size()};
    }
    template<> std::vector<std::byte> read<std::byte>(std::istream& input)
    {
      static_assert(sizeof(std::byte) == sizeof(char));
      auto buffer = read<char>(input);
      return buffer
        | ranges::views::transform([](char c){ return std::byte(static_cast<unsigned char>(c)); })
        | ranges::to<std::vector<std::byte>>;
    }
    template<> std::string read<char>(std::istream& input)
      { return std::string{std::istreambuf_iterator<char>{input}, {}}; }
  }
}
