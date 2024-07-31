# pragma once
# include <ufo/unfold.hpp>

namespace ufo
{
  class PlotSolver : public Solver
  {
    public:
      struct InputType
      {
        Eigen::Matrix3d PrimativeCell;

        struct FigureConfigType
        {
          std::vector<std::vector<Eigen::Vector3d>> Qpoints;
          std::pair<unsigned, unsigned> Resolution;
          std::pair<double, double> Range;
          std::optional<std::vector<double>> YTicks;
          DataFile PictureFile;
          std::optional<std::vector<DataFile>> DataFiles;
        };
        std::vector<FigureConfigType> Figures;

        struct UnfoldedDataType : public UnfoldSolver::OutputType
        {
          UnfoldedDataType(std::string filename);
          UnfoldedDataType() = default;
        };
        DataFile UnfoldedDataFile;
        UnfoldedDataType UnfoldedData;

        InputType(std::string config_file);
      };
      struct OutputType
      {
        std::vector<std::vector<double>> Values;
        std::vector<double> XTicks;
        std::vector<double> YTicks;
        std::pair<unsigned, unsigned> Resolution;
        std::pair<double, double> Range;

        OutputType() = default;
        const OutputType& write(std::string filename, std::string format) const;
        using serialize = zpp::bits::members<5>;
      };
    protected:
      InputType Input_;
      std::optional<std::vector<OutputType>> Output_;
    public:
      PlotSolver(std::string config_file);
      PlotSolver& operator()() override;

      // 根据 q 点路径, 搜索要使用的 q 点
      static std::vector<std::reference_wrapper<const UnfoldSolver::OutputType::QpointDataType>> search_qpoints
      (
        const std::pair<Eigen::Vector3d, Eigen::Vector3d>& path,
        const decltype(InputType::UnfoldedDataType::QpointData)& available_qpoints,
        double threshold, bool exclude_endpoint = false
      );
      // 根据搜索到的 q 点, 计算每个点的数值
      static std::tuple<std::vector<std::vector<double>>, std::vector<double>> calculate_values
      (
        const Eigen::Matrix3d primative_cell,
        const std::vector<std::pair<Eigen::Vector3d, Eigen::Vector3d>>& path,
        const std::vector<std::vector<std::reference_wrapper<const UnfoldSolver::OutputType::QpointDataType>>>& qpoints,
        const decltype(InputType::FigureConfigType::Resolution)& resolution,
        const decltype(InputType::FigureConfigType::Range)& range
      );
      // 根据数值, 画图
      static void plot
      (
        const std::vector<std::vector<double>>& values,
        const std::string& filename,
        const std::vector<double>& x_ticks, const std::vector<double>& y_ticks
      );
  };
}
