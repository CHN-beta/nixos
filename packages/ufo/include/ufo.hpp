# pragma once
# include <biu.hpp>

namespace ufo
{
  // 在相位中, 约定为使用 $\exp (2 \pi i \vec{q} \cdot \vec{r})$ 来表示原子的运动状态
  //  (而不是 $\exp (-2 \pi i \vec{q} \cdot \vec{r})$)
  // 一些书定义的倒格矢中包含了 $2 \pi$ 的部分, 我们这里约定不包含这部分.
  //  也就是说, 正格子与倒格子的转置相乘, 得到单位矩阵.

  using namespace biu::literals;
  using namespace biu::stream_operators;

  void fold(std::string config_file);
  void unfold(std::string config_file);
  void plot_band(std::string config_file);
  void plot_point(std::string config_file);

  // unfold 和 plot 都需要用到这个，所以写出来
  struct UnfoldOutput
  {
    Eigen::Matrix3d PrimativeCell;
    Eigen::Matrix3i SuperCellTransformation;
    Eigen::Vector3i SuperCellMultiplier;
    Eigen::Matrix3d SuperCellDeformation;
    std::optional<std::vector<std::size_t>> SelectedAtoms;

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

    struct MetaQpointDataType
    {
      // Q 点的坐标，单位为单胞的倒格矢
      Eigen::Vector3d Qpoint;

      // 关于这个 Q 点上各个模式的数据
      struct ModeDataType
      {
        // 模式的频率，单位为 THz
        double Frequency;
        // 模式中各个原子的运动状态
        // 这个数据应当是这样得到的：动态矩阵的 eigenvector 乘以 $\exp(-2 \pi i \vec q \cdot \vec r)$
        // 这个数据可以认为是原子位移中, 关于超胞有周期性的那一部分, 再乘以原子质量的开方.
        // 这个数据会在 unfold 时被归一化
        Eigen::MatrixX3cd AtomMovement;
      };
      std::vector<ModeDataType> ModeData;
    };
    std::vector<MetaQpointDataType> MetaQpointData;

    using serialize = zpp::bits::members<7>;
  };
}
