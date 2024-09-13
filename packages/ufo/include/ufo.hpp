# pragma once
# include <biu.hpp>

namespace ufo
{
  // 在相位中, 约定为使用 $\exp (2 \pi i \vec{q} \cdot \vec{r})$ 来表示原子的运动状态
  //  (而不是 $\exp (-2 \pi i \vec{q} \cdot \vec{r})$)
  // 一些书定义的倒格矢中包含了 $2 \pi$ 的部分, 我们这里约定不包含这部分.
  //  也就是说, 正格子与倒格子的转置相乘, 得到单位矩阵.

  using namespace biu::literals;

  void fold(std::string config_file);
  void unfold(std::string config_file);
  void plot_band(std::string config_file);
  void plot_point(std::string config_file);

  // unfold 和 plot 都需要用到这个，所以写出来
  // TODO: 把输入的数据也保留进来
  struct UnfoldOutput
  {
    Eigen::Matrix3d PrimativeCell;

    // 关于各个 Q 点的数据
    struct QpointDataType
    {
      // Q 点的坐标，单位为单胞的倒格矢
      Eigen::Vector3d Qpoint;

      // 来源于哪个 Q 点, 单位为超胞的倒格矢
      Eigen::Vector3d Source;
      std::size_t SourceIndex;

      // 关于这个 Q 点上各个模式的数据
      struct ModeDataType
      {
        // 模式的频率，单位为 THz
        double Frequency;
        // 模式的权重
        double Weight;
      };
      std::vector<ModeDataType> ModeData;
    };
    std::vector<QpointDataType> QpointData;
  };
}