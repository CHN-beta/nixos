# include <ufo.hpp>
# include <thread>
# include <syncstream>
# include <execution>

void ufo::unfold(std::string config_file)
{
  // 反折叠的原理: 将超胞中的原子运动状态, 投影到一组平面波构成的基矢中.
  // 每一个平面波的波矢由两部分相加得到: 一部分是单胞倒格子的整数倍, 所取的个数有一定任意性, 论文中建议取大约单胞中原子个数那么多个;
  //  对于没有缺陷的情况, 取一个应该就足够了.
  // 这些平面波以原胞为周期。
  // 另一部分是超胞倒格子的整数倍, 取 n 个, n 为超胞对应的单胞的倍数, 其实也就是倒空间中单胞对应倒格子中超胞的格点.
  // 只要第一部分取得足够多, 那么单胞中原子的状态就可以完全被这些平面波描述.
  // 将超胞中原子的运动状态投影到这些基矢上, 计算出投影的系数, 就可以将超胞的原子运动状态分解到单胞中的多个 q 点上.

  struct Input
  {
    // 单胞的三个格矢，每行表示一个格矢的坐标，单位为埃
    Eigen::Matrix3d PrimativeCell;

    // 单胞到超胞的格矢转换时用到的矩阵
    // SuperCellMultiplier 是一个三维列向量且各个元素都是整数，表示单胞在各个方向扩大到多少倍之后，可以得到和超胞一样的体积
    // SuperCellDeformation 是一个行列式为 1 的矩阵，它表示经过 SuperCellMultiplier 扩大后，还需要怎样的变换才能得到超胞
    // SuperCell = (SuperCellDeformation * SuperCellMultiplier.asDiagonal()) * PrimativeCell
    // ReciprocalPrimativeCell = (SuperCellDeformation * SuperCellMultiplier.asDiagonal()).transpose()
    //  * ReciprocalSuperCell
    // Position = PositionToCell(line vector) * Cell
    // InversePosition = InversePositionToCell(line vector) * ReciprocalCell
    // PositionToSuperCell(line vector) * SuperCell = PositionToPrimativeCell(line vector) * PrimativeCell
    // ReciprocalPositionToSuperCell(line vector) * ReciprocalSuperCell
    //  = ReciprocalPositionToPrimativeCell(line vector) * ReciprocalPrimativeCell
    Eigen::Matrix3i SuperCellTransformation;

    // 在单胞内取几个平面波的基矢
    Eigen::Vector<unsigned, 3> PrimativeCellBasisNumber;

    // 超胞中原子的坐标，每行表示一个原子的坐标，单位为超胞的格矢
    Eigen::MatrixX3d AtomPositionBySuperCell;

    // 从 band.hdf5 读入 QpointData
    std::optional<std::string> QpointDataInputFile;

    // 输出到哪些文件
    struct QpointDataOutputFileType
    {
      std::string Filename;

      // 如果指定，则将结果投影到那些原子上
      std::optional<std::vector<std::size_t>> SelectedAtoms;

      // 默认输出为 zpp 文件，如果指定为 true，则输出为 yaml 文件
      std::optional<bool> OutputAsYaml;
    };
    std::vector<QpointDataOutputFileType> QpointDataOutputFile;
  };

  // 关于各个 Q 点的数据
  struct QpointData
  {
    // Q 点的坐标，单位为超胞的倒格矢
    Eigen::Vector3d Qpoint;

    // 关于这个 Q 点上各个模式的数据
    struct ModeDataType
    {
      // 模式的频率，单位为 THz
      double Frequency;
      // 模式中各个原子的运动状态
      // 这个数据应当是这样得到的：动态矩阵的 eigenvector 乘以 $\exp(-2 \pi i \vec q \cdot \vec r)$
      // 这个数据可以认为是原子位移中, 关于超胞有周期性的那一部分, 再乘以原子质量的开方.
      // 这个数据在读入后会被立即归一化.
      Eigen::MatrixX3cd AtomMovement;
    };
    std::vector<ModeDataType> ModeData;
  };

  // 从文件中读取 QpointData
  auto read_qpoint_data = [](std::string filename)
  {
    // 读入原始数据
    // phonopy 的输出有两种可能
    // 直接指定计算的 q 点时，frequency 是 2 维，这时第一个维度是 q 点，第二个维度是不同模式
    // 计算能带时，frequency 是 3 维，相比于二维的情况多了第一个维度，表示 q 点所在路径
    // qpoint 或 path，以及 eigenvector 也有类似的变化
    // eigenvector 是三维或四维的数组，后两个维度分别表示原子运动和模式（而不是模式和原子），
    //  因为后两个维度的尺寸总是一样的（模式个数等于原子坐标个数），非常容易搞错
    std::vector<std::array<double, 3>> qpoint;
    std::vector<std::vector<double>> frequency;
    std::vector<std::vector<std::vector<biu::PhonopyComplex>>> eigenvector_vector;
    auto file = biu::Hdf5file(filename);

    if (file.File.getDataSet("/frequency").getDimensions().size() == 2)
      file.read("/frequency", frequency)
        .read("/eigenvector", eigenvector_vector)
        .read("/qpoint", qpoint);
    else
    {
      std::vector<std::vector<std::array<double, 3>>> temp_path;
      std::vector<std::vector<std::vector<double>>> temp_frequency;
      std::vector<std::vector<std::vector<std::vector<biu::PhonopyComplex>>>> temp_eigenvector_vector;
      file.read("/frequency", temp_frequency)
        .read("/eigenvector", temp_eigenvector_vector)
        .read("/path", temp_path);
      frequency = temp_frequency | ranges::views::join | ranges::to_vector;
      qpoint = temp_path | ranges::views::join | ranges::to_vector;
      eigenvector_vector = temp_eigenvector_vector | ranges::views::join | ranges::to_vector;
    }

    // 整理得到结果
    auto number_of_qpoints = frequency.size(), num_of_modes = frequency[0].size();
    std::vector<QpointData> qpoint_data(number_of_qpoints);
    for (unsigned i = 0; i < number_of_qpoints; i++)
    {
      qpoint_data[i].Qpoint = qpoint[i] | biu::toEigen<>;
      qpoint_data[i].ModeData.resize(num_of_modes);
      for (unsigned j = 0; j < num_of_modes; j++)
      {
        qpoint_data[i].ModeData[j].Frequency = frequency[i][j];
        auto n_modes = eigenvector_vector[i].size() / 3;
        Eigen::MatrixX3cd eigenvectors(n_modes, 3);
        for (unsigned k = 0; k < n_modes; k++) for (unsigned l = 0; l < 3; l++) eigenvectors(k, l)
          = eigenvector_vector[i][k * 3 + l][j].r + eigenvector_vector[i][k * 3 + l][j].i * 1i;
        // 原则上讲，需要对读入的原子运动状态作相位转换, 使得它们与我们的约定一致(对超胞周期性重复)，但这个转换 phonopy 已经做了
        // 这里还要需要做归一化处理 (指将数据简单地作为向量处理的归一化)
        qpoint_data[i].ModeData[j].AtomMovement = eigenvectors / eigenvectors.norm();
      }
    }
    return qpoint_data;
  };

  // 将 SuperCellTransformation 矩阵分解为 SuperCellDeformation 和 SuperCellMultiplier
  auto decompose_transformation = [](Eigen::Matrix3i transformation)
    -> std::pair<Eigen::Matrix3d, Eigen::Vector3i>
  {
    // 三种整数基础矩阵
    struct Multiply { unsigned at; int multiply; };
    struct Add { unsigned from, to; int multiply; };
    struct Exchange { unsigned from, to; };

    // 将 SuperCellTransformation 分解为一系列基础矩阵的乘积，并将这些基础矩阵从左到右输出
    auto decompose = [](Eigen::Matrix3i matrix)
      -> concurrencpp::generator<std::variant<Add, Exchange, Multiply>>
    {
      // 首先将第一列转变为只有一个元素不为零
      while (true)
      {
        // 统计第一列零的个数，以及非零值中，绝对值最大和最小的行
        std::multimap<unsigned, unsigned> values;
        for (unsigned i = 0; i < 3; i++) if (matrix(i, 0) != 0)
          values.insert({std::abs(matrix(i, 0)), i});
        // 如果都是零，报错
        if (values.size() == 0) [[unlikely]] throw std::runtime_error("Transformation matrix is singular.");
        // 如果只有一个非零值，那么将它移到第一行
        if (values.size() == 1)
        {
          if (auto i = values.begin()->second; i != 0)
          {
            auto transform = Eigen::Matrix3i::Identity().eval();
            transform(0, 0) = 0;
            transform(0, i) = 1;
            transform(i, i) = 0;
            transform(i, 0) = 1;
            matrix = transform * matrix;
            co_yield Exchange{0, i};
          }
          break;
        }
        // 否则，将最小值乘以整数倍，加到最大值上
        else
        {
          auto i_max = values.rbegin()->second;
          auto i_min = values.begin()->second;
          auto multiply = -matrix(i_max, 0) / matrix(i_min, 0);
          auto transform = Eigen::Matrix3i::Identity().eval();
          transform(i_max, i_min) = multiply;
          matrix = transform * matrix;
          // 分解出来的矩阵需要是操作的逆
          co_yield Add{i_min, i_max, -multiply};
        }
      }
      // 然后将第二列后两行转变为只有一个元素不为零
      while (true)
      {
        // 如果都是零，报错
        if (matrix(1, 1) == 0 && matrix(2, 1) == 0) [[unlikely]]
          throw std::runtime_error("Transformation matrix is singular.");
        // 如果只有一个不是零，将它移到第二行
        else if (matrix(2, 1) == 0) break;
        else if (matrix(1, 1) == 0)
        {
          Eigen::Matrix3i transform{{1, 0, 0}, {0, 0, 1}, {0, 1, 0}};
          matrix = transform * matrix;
          co_yield Exchange{1, 2};
          break;
        }
        // 否则，将最小值乘以整数倍，加到最大值上
        else
        {
          unsigned i_max, i_min;
          if (std::abs(matrix(1, 1)) > std::abs(matrix(2, 1))) { i_max = 1; i_min = 2; }
          else { i_max = 2; i_min = 1; }
          auto multiply = -matrix(i_max, 1) / matrix(i_min, 1);
          auto transform = Eigen::Matrix3i::Identity().eval();
          transform(i_max, i_min) = multiply;
          matrix = transform * matrix;
          co_yield Add{i_min, i_max, -multiply};
        }
      }
      // 然后将第三行第三列元素化为 1
      if (matrix(2, 2) == 0) [[unlikely]] throw std::runtime_error("Transformation matrix is singular.");
      else if (matrix(2, 2) != 1)
      {
        co_yield Multiply{2, matrix(2, 2)};
        matrix(2, 2) = 1;
      }
      // 将第三列的其它元素化为 0
      if (matrix(0, 2) != 0)
        { co_yield Add{2, 0, matrix(0, 2)}; matrix(0, 2) = 0; }
      if (matrix(1, 2) != 0)
        { co_yield Add{2, 1, matrix(1, 2)}; matrix(1, 2) = 0; }
      // 将第二行第二列元素化为 1
      if (matrix(1, 1) == 0) [[unlikely]] throw std::runtime_error("Transformation matrix is singular.");
      else if (matrix(1, 1) != 1)
        { co_yield Multiply{1, matrix(1, 1)}; matrix(1, 1) = 1; }
      // 将第一行第二列元素化为 0
      if (matrix(0, 1) != 0)
        { co_yield Add{1, 0, matrix(0, 1)}; matrix(0, 1) = 0; }
      // 将第一行第一列元素化为 1
      if (matrix(0, 0) == 0) [[unlikely]] throw std::runtime_error("Transformation matrix is singular.");
      else if (matrix(0, 0) != 1)
        { co_yield Multiply{0, matrix(0, 0)}; matrix(0, 0) = 1; }
    };

    auto deformatin = Eigen::Matrix3d::Identity().eval();
    auto multiplier = Eigen::Vector3i::Ones().eval();
    for (auto i : decompose(transformation))
    {
      if (std::holds_alternative<Multiply>(i))
      {
        auto [at, multiply] = std::get<Multiply>(i);
        multiplier(at) *= multiply;
      }
      else if (std::holds_alternative<Add>(i))
      {
        auto [from, to, multiply] = std::get<Add>(i);
        auto transform = Eigen::Matrix3d::Identity().eval();
        transform(to, from) = static_cast<double>(multiply) / multiplier(from) * multiplier(to);
        deformatin = deformatin * transform;
      }
      else if (std::holds_alternative<Exchange>(i))
      {
        auto [from, to] = std::get<Exchange>(i);
        deformatin.col(from).swap(deformatin.col(to));
        std::swap(multiplier(from), multiplier(to));
      }
    }
    return {deformatin, multiplier};
  };

  // 构建基
  // 每个 q 点对应一组 sub qpoint。不同的 q 点所对应的 sub qpoint 是不一样的，但 sub qpoint 与 q 点的相对位移在不同 q 点之间是相同的。
  // 由于基只与这个相对位置有关（也就是说，不同 q 点的基是一样的），因此可以先计算出所有的基，这样降低计算量。
  // 外层下标对应超胞倒格子的整数倍那部分(第二部分), 也就是不同的 sub qpoint
  // 内层下标对应单胞倒格子的整数倍那部分(第一部分), 也就是 sub qpoint 上的不同平面波（取的数量越多，结果越精确）
  auto construct_basis = []
  (
    Eigen::Matrix3d primative_cell, Eigen::Vector3i super_cell_multiplier,
    Eigen::Vector<unsigned, 3> primative_cell_basis_number, Eigen::MatrixX3d atom_position
  )
  {
    std::vector<std::vector<Eigen::VectorXcd>> basis(super_cell_multiplier.prod());
    // diff_of_sub_qpoint 表示 sub qpoint 与 qpoint 的相对位置，单位为超胞的倒格矢
    for (auto [diff_of_sub_qpoint_by_reciprocal_modified_super_cell, i_of_sub_qpoint]
      : biu::sequence(super_cell_multiplier))
    {
      basis[i_of_sub_qpoint].resize(primative_cell_basis_number.prod());
      for (auto [xyz_of_basis, i_of_basis]
        : biu::sequence(primative_cell_basis_number))
      {
        // 计算 q 点的坐标, 单位为单胞的倒格矢
        auto diff_of_sub_qpoint_by_reciprocal_primative_cell = xyz_of_basis.cast<double>()
          + super_cell_multiplier.cast<double>().cwiseInverse().asDiagonal()
          * diff_of_sub_qpoint_by_reciprocal_modified_super_cell.cast<double>();
        // DiffOfSubQpoint
        //  = (DiffOfSubQpointByReciprocalPrimativeCell.transpose() * ReciprocalPrimativeCell).transpose()
        // ReciprocalPrimativeCell = PrimativeCell.transpose().inverse()
        // SuperCell = SuperCellTransformation * PrimativeCell
        // ReciprocalSuperCell = SuperCell.transpose().inverse()
        // AtomPosition = AtomPositionBySuperCell * SuperCell.transpose()
        // 整理得到：
        // 
        // 将单位转换为埃^-1
        auto diff_of_sub_qpoint = (diff_of_sub_qpoint_by_reciprocal_primative_cell.transpose()
          * (primative_cell.transpose().inverse())).transpose();
        // 计算基矢
        basis[i_of_sub_qpoint][i_of_basis]
          = (2i * std::numbers::pi_v<double> * (atom_position * diff_of_sub_qpoint)).array().exp();
      }
    }
    return basis;
  };

  // 计算从超胞到原胞的投影系数（不是分原子的投影系数），是反折叠的核心步骤
  // 返回的投影系数是一个三维数组，第一维对应不同的 q 点，第二维对应不同的模式，第三维对应不同的 sub qpoint
  auto construct_projection_coefficient = []
  (
    const std::vector<std::vector<Eigen::VectorXcd>>& basis,
    // 实际上只需要其中的 AtomMovement
    const std::vector<QpointData>& qpoint_data,
    std::atomic<unsigned>& number_of_finished_modes
  )
  {
    // 将所有的模式取出，组成一个一维数组，稍后并行计算
    std::vector<std::reference_wrapper<const Eigen::MatrixX3cd>> mode_data;
    for (auto& qpoint : qpoint_data) for (auto& mode : qpoint.ModeData)
      mode_data.emplace_back(mode.AtomMovement);
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
        for (auto& _ : projection_coefficient) _ /= sum;
        number_of_finished_modes++;
        return projection_coefficient;
      }
    );
    // 将计算得到的投影系数重新组装成三维数组
    // 第一维是 meta qpoint，第二维是模式，第三维是 sub qpoint
    std::vector<std::vector<std::vector<double>>> projection_coefficient_output;
    for
    (
      unsigned i_of_meta_qpoint = 0, num_of_mode_manipulated = 0;
      i_of_meta_qpoint < qpoint_data.size(); i_of_meta_qpoint++
    )
      projection_coefficient_output.emplace_back
      (
        projection_coefficient.begin() + num_of_mode_manipulated,
        projection_coefficient.begin() + num_of_mode_manipulated + qpoint_data[i_of_meta_qpoint].ModeData.size()
      );
    return projection_coefficient_output;
  };

  // 组装输出，即将投影系数应用到原始数据上
  auto construct_output = []
  (
    const Eigen::Matrix3d& primative_cell,
    const Eigen::Vector3i& super_cell_multiplier,
    const Eigen::Matrix3d& super_cell_deformation,
    const std::vector<std::vector<std::vector<double>>>& projection_coefficient,
    const std::vector<QpointData>& qpoint_data,
    const std::optional<std::vector<std::size_t>>& selected_atoms
  )
  {
    UnfoldOutput output;
    output.PrimativeCell = primative_cell;
    for (unsigned i_of_meta_qpoint = 0; i_of_meta_qpoint < qpoint_data.size(); i_of_meta_qpoint++)
    {
      // 如果需要投影到特定的原子上，需要先计算当前 meta qpoint 的不同模式的投影系数
      std::optional<std::vector<double>> projection_coefficient_on_atoms;
      if (selected_atoms)
      {
        projection_coefficient_on_atoms.emplace();
        for (std::size_t i = 0; i < qpoint_data[i_of_meta_qpoint].ModeData.size(); i++)
        {
          projection_coefficient_on_atoms.value().emplace_back(0);
          for (auto atom : *selected_atoms)
            projection_coefficient_on_atoms.value().back()
              += qpoint_data[i_of_meta_qpoint].ModeData[i].AtomMovement.row(atom).array().abs2().sum();
        }
      }

      for
      (
        auto [diff_of_sub_qpoint_by_reciprocal_modified_super_cell, i_of_sub_qpoint]
          : biu::sequence(super_cell_multiplier)
      )
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
            diff_of_sub_qpoint_by_reciprocal_modified_super_cell.cast<double>()
              + super_cell_deformation.inverse() * qpoint_data[i_of_meta_qpoint].Qpoint
          )
        ).eval();
        _.Qpoint = sub_qpoint_by_reciprocal_primative_cell.array()
          - sub_qpoint_by_reciprocal_primative_cell.array().floor();
        _.Source = qpoint_data[i_of_meta_qpoint].Qpoint;
        _.SourceIndex = i_of_meta_qpoint;

        for (unsigned i_of_mode = 0; i_of_mode < qpoint_data[i_of_meta_qpoint].ModeData.size(); i_of_mode++)
        {
          auto& __ = _.ModeData.emplace_back();
          __.Frequency = qpoint_data[i_of_meta_qpoint].ModeData[i_of_mode].Frequency;
          __.Weight = projection_coefficient[i_of_meta_qpoint][i_of_mode][i_of_sub_qpoint];
          if (selected_atoms)
            __.Weight *= projection_coefficient_on_atoms.value()[i_of_mode];
        }
      }
    }
    return output;
  };

  std::clog << "Reading input file... " << std::flush;
  auto input = YAML::LoadFile(config_file).as<Input>();
  auto qpoint_data
    = read_qpoint_data(input.QpointDataInputFile.value_or("band.hdf5"));
  std::clog << "Done." << std::endl;

  std::clog << "Constructing basis... " << std::flush;
  auto [super_cell_deformation, super_cell_multiplier]
    = decompose_transformation(input.SuperCellTransformation);
  auto basis = construct_basis
  (
    input.PrimativeCell, super_cell_multiplier,
    input.PrimativeCellBasisNumber,
    input.AtomPositionBySuperCell
      * (input.SuperCellTransformation.cast<double>() * input.PrimativeCell).transpose()
  );
  std::clog << "Done." << std::endl;

  std::clog << "Calculating projection coefficient... " << std::flush;
  // 用来在屏幕上输出进度的计数器和线程
  std::atomic<unsigned> number_of_finished_modes(0);
  auto number_of_modes = ranges::accumulate
  (
    qpoint_data
      | ranges::views::transform([](const auto& qpoint) { return qpoint.ModeData.size(); }),
    0ul
  );
  std::atomic<bool> finished;
  std::thread print_thread([&]
  {
    while (true)
    {
      std::osyncstream(std::clog)
        << "\rCalculating projection coefficient... ({}/{})"_f(number_of_finished_modes, number_of_modes)
        << std::flush;
      std::this_thread::sleep_for(100ms);
      if (finished) break;
    }
  });
  auto projection_coefficient = construct_projection_coefficient(basis, qpoint_data, number_of_finished_modes);
  finished = true;
  print_thread.join();
  std::clog << "\33[2K\rCalculating projection coefficient... Done." << std::endl;

  std::clog << "Writing data... " << std::flush;
  for (auto& output_file : input.QpointDataOutputFile)
  {
    auto output = construct_output
    (
      input.PrimativeCell, super_cell_multiplier, super_cell_deformation,
      projection_coefficient, qpoint_data, output_file.SelectedAtoms
    );
    if (output_file.OutputAsYaml.value_or(false)) std::ofstream(output_file.Filename) << YAML::Node(output);
    else std::ofstream(output_file.Filename, std::ios::binary) << biu::serialize<char>(output);
  }
  std::clog << "Done." << std::endl;
}
