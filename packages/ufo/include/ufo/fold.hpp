# pragma once
# include <ufo/solver.hpp>

namespace ufo
{
  class FoldSolver : public Solver
  {
    public:
      struct InputType
      {
        Eigen::Matrix<int, 3, 3> SuperCellTransformation;
        std::vector<Eigen::Vector3d> Qpoints;
        DataFile OutputFile;

        InputType(std::string config_file);
      };
      struct OutputType
      {
        std::vector<Eigen::Vector3d> Qpoints;
        using serialize = zpp::bits::members<1>;
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
        Eigen::Matrix<int, 3, 3> super_cell_transformation
      );
  };
}