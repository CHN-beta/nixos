# include <ufo.hpp>

void ufo::raman_create_displacement(std::string config_file)
{
  struct Input
  {
    std::string UnfoldedDataFile;
    // 搜索位于 Gamma 点的 q 点时，使用的阈值，单位为埃^-1，默认为 0.01
    std::optional<double> ThresholdWhenSearchingQpoints;
    // 搜索权重非零的模式时，使用的阈值，默认为 0.01
    std::optional<double> ThresholdWhenSearchingModes;
    // 所有原子的符号
    std::vector<std::string> AtomSymbols;
    // 各种原子的质量，单位为原子质量
    std::map<std::string, double> AtomMasses;
    // 原子最大位移大小，单位为埃
    double MaxDisplacement;
    // 超胞，单位为埃
    Eigen::Matrix3d SuperCell;
    // 超胞中各个原子的坐标，单位为超胞的格矢
    Eigen::MatrixX3d AtomPositions;
    // 输出的POSCAR所在的目录
    std::string OutputPoscarDirectory;
    // 输出的数据文件名
    std::string OutputDataFile;
  };
  struct Output
  {
    struct ModeData_t
    {
      std::size_t MetaQpointIndex;
      std::size_t ModeIndex;
      // 每个原子的位移，单位为埃
      Eigen::MatrixX3d AtomMovement;
    };
    std::vector<ModeData_t> ModeData;
    using serialize = zpp::bits::members<1>;
  };

  // 假定同类型的原子一定写在一起
  auto generate_poscar = []
  (
    Eigen::Matrix3d SuperCell, Eigen::MatrixX3d AtomPositions, std::vector<std::string> AtomSymbols
  )
  {
    std::stringstream ss;
    ss << "some random comment to make VASP happy\n1.0\n";
    for (std::size_t i = 0; i < 3; i++)
    {
      for (std::size_t j = 0; j < 3; j++) ss << SuperCell(i, j) << " ";
      ss << std::endl;
    }
    auto atom_symbols = AtomSymbols | ranges::views::chunk_by(std::ranges::equal_to{});
    ss << "{}\n"_f(ranges::accumulate
    (
      atom_symbols | ranges::views::transform([](auto&& chunk) { return chunk[0]; }),
      ""s, [](auto&& a, auto&& b) { return a + " " + b; }
    ));
    ss << "{}\n"_f(ranges::accumulate
    (
      atom_symbols | ranges::views::transform([](auto&& chunk) { return chunk.size(); }),
      ""s, [](auto&& a, auto&& b) { return a + " " + std::to_string(b); }
    ));
    ss << "Direct\n";
    for (const auto& position : AtomPositions.rowwise())
    {
      for (std::size_t i = 0; i < 3; i++) ss << position(i) << " ";
      ss << std::endl;
    }
    return ss.str();
  };

  auto input = YAML::LoadFile(config_file).as<Input>();
  auto unfolded_data = biu::deserialize<UnfoldOutput>
    (biu::read<std::byte>(input.UnfoldedDataFile));
  Output output;

  // 搜索满足条件的模式，找到满足条件的模式后，就将 MetaQpoint 的索引加入到 output 中
  // 之所以使用 MetaQpoint 的索引而不是 Qpoint 的索引，是因为 Qpoint 中可能有指向同一个 MetaQpoint 中模式的不同模式都满足要求
  // 如果写入 Qpoint 的索引，就会重复而增加之后的计算量
  std::set<std::pair<std::size_t, std::size_t>> selected_modes;
  for (const auto& qpoint : unfolded_data.QpointData)
  {
    if
    (
      (unfolded_data.PrimativeCell.reverse().transpose() * qpoint.Qpoint).norm()
        > input.ThresholdWhenSearchingQpoints.value_or(0.01)
    )
      continue;
    for (std::size_t i = 0; i < qpoint.ModeData.size(); i++)
    {
      if (qpoint.ModeData[i].Weight < input.ThresholdWhenSearchingModes.value_or(0.01)) continue;
      selected_modes.insert({qpoint.SourceIndex, i});
    }
  }

  // 构造输出数据
  for (auto [i, j] : selected_modes)
  {
    auto& mode_data = output.ModeData.emplace_back();
    mode_data.MetaQpointIndex = i;
    mode_data.ModeIndex = j;
    // 未归一化的位移, 假定虚部总是为零
    auto atom_movement =
      unfolded_data.MetaQpointData[i].ModeData[j].AtomMovement.real().cwiseProduct
      (
        (
          input.AtomSymbols
            | ranges::views::transform([&](const auto& symbol)
              { return input.AtomMasses.at(symbol); })
            | ranges::to_vector
            | biu::toEigen<>
        ).cwiseSqrt().cwiseInverse().rowwise().replicate(3)
      ).eval();
    // 归一化
    mode_data.AtomMovement = atom_movement / atom_movement.rowwise().norm().maxCoeff() * input.MaxDisplacement;
  }

  // 输出
  std::ofstream(input.OutputDataFile, std::ios::binary) << biu::serialize<char>(output);
  for (std::size_t i = 0; i < output.ModeData.size(); i++)
  {
    std::filesystem::create_directories(input.OutputPoscarDirectory + "/" + std::to_string(i));
    std::ofstream(input.OutputPoscarDirectory + "/" + std::to_string(i) + "/POSCAR") << generate_poscar
    (
      input.SuperCell,
      input.AtomPositions + output.ModeData[i].AtomMovement * input.SuperCell.inverse(),
      input.AtomSymbols
    );
  }
  std::filesystem::create_directories(input.OutputPoscarDirectory + "/original");
  std::ofstream(input.OutputPoscarDirectory + "/original/POSCAR") << generate_poscar
  (
    input.SuperCell,
    input.AtomPositions,
    input.AtomSymbols
  );
}
