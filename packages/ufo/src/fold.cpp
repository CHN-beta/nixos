# include <ufo.hpp>

void ufo::fold(std::string config_file)
{
  struct Input
  {
    Eigen::Matrix3d SuperCellDeformation;
    Eigen::Vector3i SuperCellMultiplier;
    std::vector<Eigen::Vector3d> Qpoints;
    std::optional<std::string> OutputFile;
  };
  struct Output
  {
    std::vector<Eigen::Vector3d> Qpoints;
  };
  auto fold = []
  (
    Eigen::Vector3d qpoint_in_reciprocal_primitive_cell_by_reciprocal_primitive_cell,
    Eigen::Matrix3d super_cell_transformation
  ) -> Eigen::Vector3d
  {
    /*
      首先需要将 q 点坐标的单位转换为 ModifiedSuperCell 的格矢，可知：
      QpointByReciprocalModifiedSuperCell = SuperCellMultiplier * QpointByReciprocalPrimitiveCell;
      接下来考虑将 q 点坐标的单位转换为 SuperCell 的格矢
      ModifiedSuperCell = SuperCellMultiplier * PrimativeCell;
      SuperCell = SuperCellDeformation * ModifiedSuperCell;
      ReciprocalModifiedSuperCell = ModifiedSuperCell.inverse().transpose();
      ReciprocalSuperCell = SuperCell.inverse().transpose();
      Qpoint = QpointByReciprocalModifiedSuperCell.transpose() * ReciprocalModifiedSuperCell;
      Qpoint = QpointByReciprocalSuperCell.transpose() * ReciprocalSuperCell;
      整理可以得到:
      QpointByReciprocalSuperCell = SuperCellDeformation * QpointByReciprocalModifiedSuperCell;
      两个式子结合，可以得到：
      QpointByReciprocalSuperCell = SuperCellDeformation * SuperCellMultiplier * QpointByReciprocalPrimitiveCell;
    */
    auto qpoint_by_reciprocal_super_cell =
    (
      super_cell_transformation * qpoint_in_reciprocal_primitive_cell_by_reciprocal_primitive_cell
    ).eval();
    /*
      到目前为止，我们还没有移动过 q 点的坐标。现在，我们将它移动整数个 ReciprocalSuperCell，直到它落在超胞的倒格子中。
      这等价于直接取 QpointByReciprocalSuperCell - QpointByReciprocalSuperCell.floor()。
    */
    return (qpoint_by_reciprocal_super_cell.array() - qpoint_by_reciprocal_super_cell.array().floor()).matrix();
  };
  auto input = YAML::LoadFile(config_file).as<Input>();
  Output output;
  output.Qpoints = input.Qpoints
    | ranges::views::transform([&](auto& qpoint)
    {
      return fold(qpoint, input.SuperCellDeformation * input.SuperCellMultiplier.cast<double>().asDiagonal());
    })
    | ranges::to_vector;
  
  // 默认的输出太丑了，但是不想手动写了，忍一下
  std::ofstream(input.OutputFile.value_or("output.yaml")) << YAML::Node(output);
}
