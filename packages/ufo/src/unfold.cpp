# include <ufo/unfold.hpp>

namespace ufo
{
  UnfoldSolver::InputType::InputType(std::string filename)
  {
    // read main input file
    {
      auto node = YAML::LoadFile(filename);
        for (unsigned i = 0; i < 3; i++)
          for (unsigned j = 0; j < 3; j++)
            PrimativeCell(i, j) = node["PrimativeCell"][i][j].as<double>();

      for (unsigned i = 0; i < 3; i++)
        SuperCellMultiplier(i) = node["SuperCellMultiplier"][i].as<int>();

      if (auto value = node["SuperCellDeformation"])
      {
        SuperCellDeformation.emplace();
        for (unsigned i = 0; i < 3; i++)
          for (unsigned j = 0; j < 3; j++)
            (*SuperCellDeformation)(i, j) = value[i][j].as<double>();
      }

      for (unsigned i = 0; i < 3; i++)
        PrimativeCellBasisNumber(i) = node["PrimativeCellBasisNumber"][i].as<int>();

      AtomPositionInputFile = DataFile
      (
        node["AtomPositionInputFile"], {"yaml"},
        filename, true
      );
      QpointDataInputFile = DataFile
      (
        node["QpointDataInputFile"], {"yaml", "hdf5"},
        filename, true
      );
      if (auto value = node["QpointDataOutputFile"])
      {
        QpointDataOutputFile.resize(value.size());
        for (unsigned i = 0; i < value.size(); i++)
          QpointDataOutputFile[i] = DataFile
          (
            value[i], {"yaml", "yaml-human-readable", "zpp", "hdf5"},
            filename, false
          );
      }
    }

    if (AtomPositionInputFile.Format == "yaml")
    {
      auto node = YAML::LoadFile(AtomPositionInputFile.Filename);
      std::vector<YAML::Node> points;
      if (auto _ = node["points"])
        points = _.as<std::vector<YAML::Node>>();
      else
        points = node["unit_cell"]["points"].as<std::vector<YAML::Node>>();
      auto atom_position_to_super_cell = Eigen::MatrixX3d(points.size(), 3);
      for (unsigned i = 0; i < points.size(); i++)
        for (unsigned j = 0; j < 3; j++)
          atom_position_to_super_cell(i, j) = points[i]["coordinates"][j].as<double>();
      auto super_cell = (SuperCellDeformation.value_or(Eigen::Matrix3d::Identity())
        * SuperCellMultiplier.cast<double>().asDiagonal() * PrimativeCell).eval();
      AtomPosition = atom_position_to_super_cell * super_cell;
    }
    if (QpointDataInputFile.Format == "yaml")
    {
      auto node = YAML::LoadFile(QpointDataInputFile.Filename);
      auto phonon = node["phonon"].as<std::vector<YAML::Node>>();
      QpointData.resize(phonon.size());
      for (unsigned i = 0; i < phonon.size(); i++)
      {
        for (unsigned j = 0; j < 3; j++)
          QpointData[i].Qpoint(j) = phonon[i]["q-position"][j].as<double>();
        auto band = phonon[i]["band"].as<std::vector<YAML::Node>>();
        QpointData[i].ModeData.resize(band.size());
        for (unsigned j = 0; j < band.size(); j++)
        {
          QpointData[i].ModeData[j].Frequency = band[j]["frequency"].as<double>();
          auto eigenvector_vectors = band[j]["eigenvector"]
            .as<std::vector<std::vector<std::vector<double>>>>();
          Eigen::MatrixX3cd eigenvectors(AtomPosition.rows(), 3);
          for (unsigned k = 0; k < AtomPosition.rows(); k++)
            for (unsigned l = 0; l < 3; l++)
              eigenvectors(k, l)
                = eigenvector_vectors[k][l][0] + 1i * eigenvector_vectors[k][l][1];
          // 需要对读入的原子运动状态作相位转换, 使得它们与我们的约定一致(对超胞周期性重复)
          // 这里还要需要做归一化处理 (指将数据简单地作为向量处理的归一化)
          auto& AtomMovement = QpointData[i].ModeData[j].AtomMovement;
          // AtomMovement = eigenvectors.array().colwise() * (-2 * std::numbers::pi_v<double> * 1i
          //   * (atom_position_to_super_cell * input.QpointData[i].Qpoint)).array().exp();
          // AtomMovement /= AtomMovement.norm();
          // phonopy 似乎已经进行了相位的转换！为什么？
          AtomMovement = eigenvectors / eigenvectors.norm();
        }
      }
    }
    else if (QpointDataInputFile.Format == "hdf5")
    {
      std::vector<std::vector<std::vector<double>>> frequency, path;
      std::vector<std::vector<std::vector<std::vector<PhonopyComplex>>>> eigenvector_vector;
      Hdf5file{}.open_for_read(QpointDataInputFile.Filename).read(frequency, "/frequency")
        .read(eigenvector_vector, "/eigenvector")
        .read(path, "/path");
      std::vector size = { frequency.size(), frequency[0].size(), frequency[0][0].size() };
      QpointData.resize(size[0] * size[1]);
      for (unsigned i = 0; i < size[0]; i++)
        for (unsigned j = 0; j < size[1]; j++)
        {
          QpointData[i * size[1] + j].Qpoint = Eigen::Vector3d(path[i][j].data());
          QpointData[i * size[1] + j].ModeData.resize(size[2]);
          for (unsigned k = 0; k < size[2]; k++)
          {
            QpointData[i * size[1] + j].ModeData[k].Frequency = frequency[i][j][k];
            Eigen::MatrixX3cd eigenvectors(AtomPosition.rows(), 3);
            for (unsigned l = 0; l < AtomPosition.rows(); l++)
              for (unsigned m = 0; m < 3; m++)
                eigenvectors(l, m)
                  = eigenvector_vector[i][j][l * 3 + m][k].r + eigenvector_vector[i][j][l * 3 + m][k].i * 1i;
            QpointData[i * size[1] + j].ModeData[k].AtomMovement = eigenvectors / eigenvectors.norm();
          }
        }
    }
  }

  void UnfoldSolver::OutputType::write
    (decltype(InputType::QpointDataOutputFile) output_files) const
  {
    for (auto& output_file : output_files)
      write(output_file.Filename, output_file.Format);
  }
  void UnfoldSolver::OutputType::write(std::string filename, std::string format, unsigned percision) const
  {
    if (format == "yaml")
      std::ofstream(filename) << [&]
      {
        std::stringstream print;
        print << "QpointData:\n";
        for (auto& qpoint: QpointData)
        {
          print << fmt::format("  - Qpoint: [ {1:.{0}f}, {2:.{0}f}, {3:.{0}f} ]\n",
            percision, qpoint.Qpoint[0], qpoint.Qpoint[1], qpoint.Qpoint[2]);
          print << fmt::format("    Source: [ {1:.{0}f}, {2:.{0}f}, {3:.{0}f} ]\n",
            percision, qpoint.Source[0], qpoint.Source[1], qpoint.Source[2]);
          print << "    ModeData:\n";
          for (auto& mode: qpoint.ModeData)
            print << fmt::format("      - {{ Frequency: {1:.{0}f}, Weight: {2:.{0}f} }}\n",
              percision, mode.Frequency, mode.Weight);
        }
        return print.str();
      }();
    else if (format == "yaml-human-readable")
    {
      std::remove_cvref_t<decltype(*this)> output;
      std::map<unsigned, std::vector<decltype(QpointData)::const_iterator>>
        meta_qpoint_to_sub_qpoint_iterators;
      for (auto it = QpointData.begin(); it != QpointData.end(); it++)
        meta_qpoint_to_sub_qpoint_iterators[it->SourceIndex_].push_back(it);
      for (auto [meta_qpoint_index, sub_qpoint_iterators] : meta_qpoint_to_sub_qpoint_iterators)
        for (auto& qpoint : sub_qpoint_iterators)
        {
          std::map<double, double> frequency_to_weight;
          for (unsigned i_of_mode = 0; i_of_mode < qpoint->ModeData.size(); i_of_mode++)
          {
            auto frequency = qpoint->ModeData[i_of_mode].Frequency;
            auto weight = qpoint->ModeData[i_of_mode].Weight;
            auto it_lower = frequency_to_weight.lower_bound(frequency - 0.1);
            auto it_upper = frequency_to_weight.upper_bound(frequency + 0.1);
            if (it_lower == it_upper)
              frequency_to_weight[frequency] = weight;
            else
            {
              auto frequency_sum = std::accumulate(it_lower, it_upper, 0.,
                [](const auto& a, const auto& b) { return a + b.first * b.second; });
              auto weight_sum = std::accumulate(it_lower, it_upper, 0.,
                [](const auto& a, const auto& b) { return a + b.second; });
              frequency_sum += frequency * weight;
              weight_sum += weight;
              frequency_to_weight.erase(it_lower, it_upper);
              frequency_to_weight[frequency_sum / weight_sum] = weight_sum;
            }
          }
          auto& _ = output.QpointData.emplace_back();
          _.Qpoint = qpoint->Qpoint;
          _.Source = qpoint->Source;
          _.SourceIndex_ = qpoint->SourceIndex_;
          for (auto [frequency, weight] : frequency_to_weight)
            if (weight > 0.1)
            {
              auto& __ = _.ModeData.emplace_back();
              __.Frequency = frequency;
              __.Weight = weight;
            }
        }
      output.write(filename, "yaml", 3);
    }
    else if (format == "zpp")
      zpp_write(*this, filename);
    else if (format == "hdf5")
    {
      std::vector<std::vector<double>> Qpoint, Source, Frequency, Weight;
      for (auto& qpoint : QpointData)
      {
        Qpoint.emplace_back(qpoint.Qpoint.data(), qpoint.Qpoint.data() + 3);
        Source.emplace_back(qpoint.Source.data(), qpoint.Source.data() + 3);
        Frequency.emplace_back();
        Weight.emplace_back();
        for (auto& mode : qpoint.ModeData)
        {
          Frequency.back().push_back(mode.Frequency);
          Weight.back().push_back(mode.Weight);
        }
      }
      Hdf5file{}.open_for_write(filename).write(Qpoint, "/Qpoint")
        .write(Source, "/Source")
        .write(Frequency, "/Frequency")
        .write(Weight, "/Weight");
    }
  }

  UnfoldSolver::UnfoldSolver(std::string config_file) : Input_([&]
  {
    std::clog << "Reading input file... " << std::flush;
    return config_file;
  }())
  {
    std::clog << "Done." << std::endl;
  }

  UnfoldSolver& UnfoldSolver::operator()()
  {
    if (!Basis_)
    {
      std::clog << "Constructing basis... " << std::flush;
      Basis_ = construct_basis
      (
        Input_.PrimativeCell, Input_.SuperCellMultiplier,
        Input_.PrimativeCellBasisNumber, Input_.AtomPosition
      );
      std::clog << "Done." << std::endl;
    }
    if (!Output_)
    {
      std::clog << "Calculating projection coefficient... " << std::flush;
      std::vector<std::reference_wrapper<const decltype
        (InputType::QpointDataType::ModeDataType::AtomMovement)>> mode_data;
      for (auto& qpoint : Input_.QpointData)
        for (auto& mode : qpoint.ModeData)
          mode_data.emplace_back(mode.AtomMovement);
      std::atomic<unsigned> number_of_finished_modes(0);
      std::thread print_thread([&]
      {
        unsigned n;
        while ((n = number_of_finished_modes) < mode_data.size())
        {
          std::osyncstream(std::cerr) << fmt::format("\rCalculating projection coefficient... ({}/{})",
            number_of_finished_modes, mode_data.size()) << std::flush;
          std::this_thread::sleep_for(100ms);
          number_of_finished_modes.wait(n);
        }
      });
      auto projection_coefficient = construct_projection_coefficient
        (*Basis_, mode_data, number_of_finished_modes);
      number_of_finished_modes = mode_data.size();
      print_thread.join();
      std::clog << "\33[2K\rCalculating projection coefficient... Done." << std::endl;

      std::clog << "Constructing output... " << std::flush;
      std::vector<std::reference_wrapper<const decltype(InputType::QpointDataType::Qpoint)>> qpoint;
      std::vector<std::vector<std::reference_wrapper<const
        decltype(InputType::QpointDataType::ModeDataType::Frequency)>>> frequency;
      for (auto& qpoint_data : Input_.QpointData)
      {
        qpoint.emplace_back(qpoint_data.Qpoint);
        frequency.emplace_back();
        for (auto& mode_data : qpoint_data.ModeData)
          frequency.back().emplace_back(mode_data.Frequency);
      }
      Output_ = construct_output
      (
        Input_.SuperCellMultiplier,
        Input_.SuperCellDeformation, qpoint, frequency, projection_coefficient
      );
      std::clog << "Done." << std::endl;
    }
    std::clog << "Writing output... " << std::flush;
    Output_->write(Input_.QpointDataOutputFile);
    std::clog << "Done." << std::endl;
    return *this;
  }

  UnfoldSolver::BasisType UnfoldSolver::construct_basis
  (
    const decltype(InputType::PrimativeCell)& primative_cell,
    const decltype(InputType::SuperCellMultiplier)& super_cell_multiplier,
    const decltype(InputType::PrimativeCellBasisNumber)& primative_cell_basis_number,
    const decltype(InputType::AtomPosition)& atom_position
  )
  {
    BasisType basis(super_cell_multiplier.prod());
    // 每个 q 点对应的一组 sub qpoint。不同的 q 点所对应的 sub qpoint 是不一样的，但 sub qpoint 与 q 点的相对位置一致。
    // 这里 xyz_of_diff_of_sub_qpoint 即表示这个相对位置，单位为超胞的倒格矢
    for (auto [xyz_of_diff_of_sub_qpoint_by_reciprocal_modified_super_cell, i_of_sub_qpoint]
      : triplet_sequence(super_cell_multiplier))
    {
      basis[i_of_sub_qpoint].resize(primative_cell_basis_number.prod());
      for (auto [xyz_of_basis, i_of_basis] : triplet_sequence(primative_cell_basis_number))
      {
        // 计算 q 点的坐标, 单位为单胞的倒格矢
        auto diff_of_sub_qpoint_by_reciprocal_primative_cell = xyz_of_basis.cast<double>()
          + super_cell_multiplier.cast<double>().cwiseInverse().asDiagonal()
          * xyz_of_diff_of_sub_qpoint_by_reciprocal_modified_super_cell.cast<double>();
        // 将 q 点坐标转换为埃^-1
        auto qpoint = (diff_of_sub_qpoint_by_reciprocal_primative_cell.transpose()
          * (primative_cell.transpose().inverse())).transpose();
        // 计算基矢
        basis[i_of_sub_qpoint][i_of_basis]
          = (2i * std::numbers::pi_v<double> * (atom_position * qpoint)).array().exp();
      }
    }
    return basis;
  }

  std::vector<std::vector<double>> UnfoldSolver::construct_projection_coefficient
  (
    const BasisType& basis,
    const std::vector<std::reference_wrapper<const decltype
      (InputType::QpointDataType::ModeDataType::AtomMovement)>>& mode_data,
    std::atomic<unsigned>& number_of_finished_modes
  )
  {
    // 第一层下标对应不同模式, 第二层下标对应这个模式在反折叠后的 q 点(sub qpoint)
    std::vector<std::vector<double>> projection_coefficient(mode_data.size());
    // 对每个模式并行
    std::transform
    (
      std::execution::par, mode_data.begin(), mode_data.end(),
      projection_coefficient.begin(), [&](const auto& mode_data)
      {
        // 这里, mode_data 和 projection_coefficient 均指对应于一个模式的数据
        std::vector<double> projection_coefficient(basis.size());
        for (unsigned i_of_sub_qpoint = 0; i_of_sub_qpoint < basis.size(); i_of_sub_qpoint++)
          // 对于 basis 中, 对应于单胞倒格子的部分, 以及对应于不同方向的部分, 分别求内积, 然后求模方和
          for (unsigned i_of_basis = 0; i_of_basis < basis[i_of_sub_qpoint].size(); i_of_basis++)
            projection_coefficient[i_of_sub_qpoint] +=
              (basis[i_of_sub_qpoint][i_of_basis].transpose().conjugate() * mode_data.get())
                .array().abs2().sum();
        // 如果是严格地将向量分解到一组完备的基矢上, 那么不需要对计算得到的权重再做归一化处理
        // 但这里并不是这样一个严格的概念. 因此对分解到各个 sub qpoint 上的权重做归一化处理
        auto sum = std::accumulate
          (projection_coefficient.begin(), projection_coefficient.end(), 0.);
        for (auto& _ : projection_coefficient)
          _ /= sum;
        number_of_finished_modes++;
        return projection_coefficient;
      }
    );
    return projection_coefficient;
  }

  UnfoldSolver::OutputType UnfoldSolver::construct_output
  (
    const decltype(InputType::SuperCellMultiplier)& super_cell_multiplier,
    const decltype(InputType::SuperCellDeformation)& super_cell_deformation,
    const std::vector<std::reference_wrapper<const decltype
      (InputType::QpointDataType::Qpoint)>>& meta_qpoint_by_reciprocal_super_cell,
    const std::vector<std::vector<std::reference_wrapper<const decltype
      (InputType::QpointDataType::ModeDataType::Frequency)>>>& frequency,
    const ProjectionCoefficientType_& projection_coefficient
  )
  {
    OutputType output;
    for
    (
      unsigned i_of_meta_qpoint = 0, num_of_mode_manipulated = 0;
      i_of_meta_qpoint < meta_qpoint_by_reciprocal_super_cell.size();
      i_of_meta_qpoint++
    )
    {
      for (auto [xyz_of_diff_of_sub_qpoint_by_reciprocal_modified_super_cell, i_of_sub_qpoint]
        : triplet_sequence(super_cell_multiplier))
      {
        auto& _ = output.QpointData.emplace_back();
        /*
          SubQpointByReciprocalModifiedSuperCell = XyzOfDiffOfSubQpointByReciprocalModifiedSuperCell +
            MetaQpointByReciprocalModifiedSuperCell;
          SubQpoint = SubQpointByReciprocalModifiedSuperCell.transpose() * ReciprocalModifiedSuperCell;
          SubQpoint = SubQpointByReciprocalPrimativeCell.transpose() * ReciprocalPrimativeCell;
          ReciprocalModifiedSuperCell = ModifiedSuperCell.inverse().transpose();
          ReciprocalPrimativeCell = PrimativeCell.inverse().transpose();
          ModifiedSuperCell = SuperCellMultiplier.asDiagonal() * PrimativeCell;
          MetaQpoint = MetaQpointByReciprocalModifiedSuperCell.transpose() * ReciprocalModifiedSuperCell;
          MetaQpoint = MetaQpointByReciprocalSuperCell.transpose() * ReciprocalSuperCell;
          ReciprocalSuperCell = SuperCell.inverse().transpose();
          ModifiedSuperCell = SuperCellDeformation * SuperCell;
          SuperCell = SuperCellMultiplier.asDiagonal() * PrimativeCell;
          整理可以得到:
          SubQpointByReciprocalPrimativeCell = SuperCellMultiplier.asDiagonal().inverse() *
            (XyzOfDiffOfSubQpointByReciprocalModifiedSuperCell +
              SuperCellDeformation.inverse() * MetaQpointByReciprocalSuperCell);
          但注意到, 这样得到的 SubQpoint 可能不在 ReciprocalPrimativeCell 中
            (当 SuperCellDeformation 不是单位矩阵时, 边界附近的一两条 SubQpoint 会出现这种情况).
          解决办法是, 在赋值时, 仅取 SubQpointByReciprocalPrimativeCell 的小数部分.
        */
        auto sub_qpoint_by_reciprocal_primative_cell =
        (
          super_cell_multiplier.cast<double>().cwiseInverse().asDiagonal()
          * (
            xyz_of_diff_of_sub_qpoint_by_reciprocal_modified_super_cell.cast<double>()
            + super_cell_deformation.value_or(Eigen::Matrix3d::Identity()).inverse()
              * meta_qpoint_by_reciprocal_super_cell[i_of_meta_qpoint].get().cast<double>()
          )
        ).eval();
        _.Qpoint = sub_qpoint_by_reciprocal_primative_cell.array()
          - sub_qpoint_by_reciprocal_primative_cell.array().floor();
        _.Source = meta_qpoint_by_reciprocal_super_cell[i_of_meta_qpoint];
        _.SourceIndex_ = i_of_meta_qpoint;
        for (unsigned i_of_mode = 0; i_of_mode < frequency[i_of_meta_qpoint].size(); i_of_mode++)
        {
          auto& __ = _.ModeData.emplace_back();
          __.Frequency = frequency[i_of_meta_qpoint][i_of_mode];
          __.Weight = projection_coefficient[num_of_mode_manipulated + i_of_mode][i_of_sub_qpoint];
        }
      }
      num_of_mode_manipulated += frequency[i_of_meta_qpoint].size();
    }
    return output;
  }
}
