# include <ufo/fold.hpp>

namespace ufo
{
  FoldSolver::InputType::InputType(std::string config_file)
  {
    auto input = YAML::LoadFile(config_file);
    for (unsigned i = 0; i < 3; i++)
      SuperCellMultiplier(i) = input["SuperCellMultiplier"][i].as<unsigned>();
    if (input["SuperCellDeformation"])
    {
      SuperCellDeformation.emplace();
      for (unsigned i = 0; i < 3; i++)
        for (unsigned j = 0; j < 3; j++)
          (*SuperCellDeformation)(i, j) = input["SuperCellDeformation"][i][j].as<double>();
    }
    for (auto& qpoint : input["Qpoints"].as<std::vector<std::vector<double>>>())
      Qpoints.push_back(Eigen::Vector3d
        {{qpoint.at(0)}, {qpoint.at(1)}, {qpoint.at(2)}});
    OutputFile = DataFile(input["OutputFile"], {"yaml"}, config_file);
  }
  void FoldSolver::OutputType::write(std::string filename) const
  {
    std::ofstream(filename) << [&]
    {
      std::stringstream print;
      print << "Qpoints:\n";
      for (auto& qpoint : Qpoints)
        print << fmt::format("  - [ {:.8f}, {:.8f}, {:.8f} ]\n", qpoint(0), qpoint(1), qpoint(2));
      return print.str();
    }();
  }

  FoldSolver::FoldSolver(std::string config_file) : Input_(config_file) {}
  FoldSolver& FoldSolver::operator()()
  {
    if (!Output_)
    {
      Output_.emplace();
      for (auto& qpoint : Input_.Qpoints)
        Output_->Qpoints.push_back(fold
        (
          qpoint, Input_.SuperCellMultiplier,
          Input_.SuperCellDeformation
        ));
    }
    Output_->write(Input_.OutputFile.Filename);
    return *this;
  }

  Eigen::Vector3d FoldSolver::fold
  (
    Eigen::Vector3d qpoint_in_reciprocal_primitive_cell_by_reciprocal_primitive_cell,
    Eigen::Vector<unsigned, 3> super_cell_multiplier,
    std::optional<Eigen::Matrix<double, 3, 3>> super_cell_deformation
  )
  {
    // 首先需要将 q 点转移到 ModifiedSuperCell 的倒格子中
    // 将 q 点坐标扩大, 然后取小数部分, 就可以了
    auto qpoint_by_reciprocal_modified_super_cell = super_cell_multiplier.cast<double>().asDiagonal()
      * qpoint_in_reciprocal_primitive_cell_by_reciprocal_primitive_cell;
    auto qpoint_in_reciprocal_modified_super_cell_by_reciprocal_modified_super_cell =
      (qpoint_by_reciprocal_modified_super_cell.array() - qpoint_by_reciprocal_modified_super_cell.array().floor())
        .matrix();
    if (!super_cell_deformation)
      return qpoint_in_reciprocal_modified_super_cell_by_reciprocal_modified_super_cell;
    /*
      对 q 点平移数个 SupreCell, 直到它落在超胞的倒格子中
      这等价于直接将 q 点坐标用 SuperCell 的倒格子表示, 然后取小数部分.
      ModifiedSuperCell = SuperCellMultiplier * PrimativeCell
      SuperCell = SuperCellDeformation * ModifiedSuperCell
      ReciprocalModifiedSuperCell = ModifiedSuperCell.inverse().transpose()
      ReciprocalSuperCell = SuperCell.inverse().transpose()
      Qpoint = QpointByReciprocalModifiedSuperCell.transpose() * ReciprocalModifiedSuperCell
      Qpoint = QpointByReciprocalSuperCell.transpose() * ReciprocalSuperCell
      整理可以得到:
      QpointByReciprocalSuperCell = SuperCellDeformation * QpointByReciprocalModifiedSuperCell
    */
    auto qpoint_in_reciprocal_modified_super_cell_by_reciprocal_super_cell =
      (*super_cell_deformation * qpoint_in_reciprocal_modified_super_cell_by_reciprocal_modified_super_cell).eval();
    auto qpoint_in_reciprocal_super_cell_by_reciprocal_super_cell =
      qpoint_in_reciprocal_modified_super_cell_by_reciprocal_super_cell.array()
      - qpoint_in_reciprocal_modified_super_cell_by_reciprocal_super_cell.array().floor();
    return qpoint_in_reciprocal_super_cell_by_reciprocal_super_cell;
  }
}
