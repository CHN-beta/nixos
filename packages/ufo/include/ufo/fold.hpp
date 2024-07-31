# pragma once
# include <ufo/solver.hpp>

namespace ufo
{
  class FoldSolver : public Solver
  {
    public:
      struct InputType
      {
        Eigen::Vector<unsigned, 3> SuperCellMultiplier;
        std::optional<Eigen::Matrix<double, 3, 3>> SuperCellDeformation;
        std::vector<Eigen::Vector3d> Qpoints;
        DataFile OutputFile;

        InputType(std::string config_file);
      };
      struct OutputType
      {
        std::vector<Eigen::Vector3d> Qpoints;
        void write(std::string filename) const;
      };
    protected:
      InputType Input_;
      std::optional<OutputType> Output_;
    public:
      FoldSolver(std::string config_file);
      FoldSolver& operator()() override;
      // return value: QpointInReciprocalSuperCellByReciprocalSuperCell
      static Eigen::Vector3d fold
      (
        Eigen::Vector3d qpoint_in_reciprocal_primitive_cell_by_reciprocal_primitive_cell,
        Eigen::Vector<unsigned, 3> super_cell_multiplier,
        std::optional<Eigen::Matrix<double, 3, 3>> super_cell_deformation
      );
  };
}