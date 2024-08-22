# pragma once
# include <any>
# include <yaml-cpp/yaml.h>
# include <matplot/matplot.h>
# include <biu.hpp>

// 在相位中, 约定为使用 $\exp (2 \pi i \vec{q} \cdot \vec{r})$ 来表示原子的运动状态
//  (而不是 $\exp (-2 \pi i \vec{q} \cdot \vec{r})$)
// 一些书定义的倒格矢中包含了 $2 \pi$ 的部分, 我们这里约定不包含这部分.
//  也就是说, 正格子与倒格子的转置相乘, 得到单位矩阵.

namespace ufo
{
  using namespace biu::literals;

  class Solver
  {
    public:
      virtual Solver& operator()() = 0;
      virtual ~Solver() = default;

      inline static void zpp_write(const auto& object, std::string filename)
      {
        auto data = biu::serialize(object);
        std::ofstream file(filename, std::ios::binary | std::ios::out);
        file.exceptions(std::ios::badbit | std::ios::failbit);
        static_assert(sizeof(std::byte) == sizeof(char));
        file.write(reinterpret_cast<const char*>(data.data()), data.size());
      }
      template <typename T> inline static T zpp_read(std::string filename)
      {
        auto input = std::ifstream(filename, std::ios::binary | std::ios::in);
        input.exceptions(std::ios::badbit | std::ios::failbit);
        static_assert(sizeof(std::byte) == sizeof(char));
        std::vector<std::byte> data;
        {
          std::vector<char> string(std::istreambuf_iterator<char>(input), {});
          data.assign
          (
            reinterpret_cast<std::byte*>(string.data()),
            reinterpret_cast<std::byte*>(string.data() + string.size())
          );
        }
        return biu::deserialize<T>(data);
      }

      struct DataFile
      {
        std::string Filename;
        std::string Format;
        std::map<std::string, std::any> ExtraParameters;
        DataFile() = default;
        DataFile
        (
          YAML::Node node, std::set<std::string> supported_format,
          std::string config_file, bool allow_same_as_config_file = false
        );
      };

  };
}
