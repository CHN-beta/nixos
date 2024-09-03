# include <ufo/fold.hpp>

namespace ufo
{
  FoldSolver::InputType::InputType(std::string config_file)
  {
    auto input = YAML::LoadFile(config_file);
    SuperCellMultiplier = input["SuperCellMultiplier"].as<std::array<unsigned, 3>>() | biu::toEigen<>;
    if (input["SuperCellDeformation"])
      SuperCellDeformation = input["SuperCellDeformation"].as<std::array<std::array<double, 3>, 3>>() | biu::toEigen<>;
    for (auto& qpoint : input["Qpoints"].as<std::vector<std::array<double, 3>>>())
      Qpoints.push_back(qpoint | biu::toEigen<>);
    OutputFile = DataFile(input["OutputFile"], {"yaml"}, config_file);
  }
  void FoldSolver::OutputType::write(std::string filename) const
  {
    std::ofstream(filename) << [&]
    {
      std::stringstream print;
      print << "Qpoints:\n";
      for (auto& qpoint : Qpoints)
        print << ("  - [ {:.8f}, {:.8f}, {:.8f} ]\n"_f(qpoint(0), qpoint(1), qpoint(2)));
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
    auto qpoint_by_reciprocal_super_cell = (super_cell_deformation.value_or(Eigen::Matrix3d::Identity())
      * super_cell_multiplier.cast<double>().asDiagonal()
      * qpoint_in_reciprocal_primitive_cell_by_reciprocal_primitive_cell).eval();
    /*
      到目前为止，我们还没有移动过 q 点的坐标。现在，我们将它移动整数个 ReciprocalSuperCell，直到它落在超胞的倒格子中。
      这等价于直接取 QpointByReciprocalSuperCell - QpointByReciprocalSuperCell.floor()。
    */
    return (qpoint_by_reciprocal_super_cell.array() - qpoint_by_reciprocal_super_cell.array().floor()).matrix();
  }
}
