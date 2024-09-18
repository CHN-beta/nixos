# include <ufo.hpp>
# include <matplot/matplot.h>
# include <boost/container/flat_map.hpp>

void ufo::plot_band(std::string config_file)
{
  struct Input
  {
    std::string UnfoldedDataFile;
    // 要画图的 q 点路径列表
    // 内层表示一个路径上的 q 点，外层表示不同的路径
    // 单位为倒格矢
    std::vector<std::vector<Eigen::Vector3d>> Qpoints;
    // 插值时使用的分辨率（不影响画出来图片的分辨率和横纵比）
    std::array<std::size_t, 2> InterpolationResolution;
    // 画图区域的y轴和x轴的比例。如果不指定，则由matplot++自动调整（通常调整为正方形，即 1）
    std::optional<double> AspectRatio;
    // 整张图片的分辨率
    std::optional<std::array<std::size_t, 2>> PictureResolution;
    // 画图的频率范围
    std::array<double, 2> FrequencyRange;
    // 搜索 q 点时的阈值，单位为埃^-1
    std::optional<double> ThresholdWhenSearchingQpoints;
    // 是否要在 y 轴上作一些标记
    std::optional<std::vector<std::pair<double, std::string>>> YTicks;
    // 是否输出图片
    std::optional<std::string> OutputPictureFile;
    // 是否输出数据，可以进一步使用 matplotlib 画图
    std::optional<std::string> OutputDataFile;
  };

  // 根据 q 点路径, 搜索要使用的 q 点，返回的是 q 点在 QpointData 中的索引以及到路径起点的距离，以及这段路径的总长度
  auto search_qpoints = []
  (
    const Eigen::Matrix3d& primative_cell,
    const std::pair<Eigen::Vector3d, Eigen::Vector3d>& path,
    const std::vector<Eigen::Vector3d>& qpoints,
    double threshold, bool exclude_endpoint = false
  )
  {
    // 对于 output 中的每一个点, 检查这个点是否在路径上. 如果在, 把它加入到 selected_qpoints 中
    // 键为这个点到起点的距离
    boost::container::flat_map<double, std::size_t> selected_qpoints;
    auto begin = (path.first.transpose() * primative_cell.reverse()).transpose().eval();
    auto end = (path.second.transpose() * primative_cell.reverse()).transpose().eval();
    for (std::size_t i = 0; i < qpoints.size(); i++)
      for (auto cell_shift
        : biu::sequence(Eigen::Vector3i(-1, -1, -1), Eigen::Vector3i(2, 2, 2)))
      {
        auto qpoint
          = ((qpoints[i] + cell_shift.first.cast<double>()).transpose() * primative_cell.reverse()).transpose().eval();
        // 计算这个点到前两个点所在直线的距离
        auto distance = (end - begin).cross(qpoint - begin).norm()
          / (path.second - path.first).norm();
        // 如果这个点到前两个点所在直线的距离小于阈值, 则认为这个点在这条直线上，但不一定在这两个点之间
        if (distance < threshold)
        {
          // 计算这个点到前两个点的距离, 两个距离都应该小于两点之间的距离
          auto distance1 = (qpoint - begin).norm();
          auto distance2 = (qpoint - end).norm();
          auto distance3 = (end - begin).norm();
          if (distance1 < distance3 + threshold && distance2 < distance3 + threshold)
            // 如果这个点不在终点处, 或者不排除终点, 则加入
            if (distance2 > threshold || !exclude_endpoint) selected_qpoints.emplace(distance1, i);
        }
      }
    // 去除非常接近的点
    for (auto it = selected_qpoints.begin(); it != selected_qpoints.end();)
    {
      auto next = std::next(it);
      if (next == selected_qpoints.end()) break;
      else if (next->first - it->first < threshold) selected_qpoints.erase(next);
      else it = next;
    }
    if (selected_qpoints.empty()) throw std::runtime_error("No q points found");
    return std::make_pair(selected_qpoints, (end - begin).norm());
  };

  // 根据搜索到的 q 点, 计算图中每个点的值
  auto calculate_values = []
  (
    // search_qpoints 的第一个返回值
    const boost::container::flat_map<double, std::size_t>& path,
    // 每一条连续路径的第一个 q 点的索引
    const std::set<std::size_t>& path_begin,
    // 所有 q 点的数据（需要用到它的频率和权重）
    const std::vector<UnfoldOutput::QpointDataType>& qpoints,
    // 用于插值的分辨率和范围
    const std::array<std::size_t, 2>& resolution,
    const std::array<double, 2>& frequency_range,
    // 路径的总长度
    double total_distance
  )
  {
    // 按比例混合两个 q 点的结果，得到可以用于画图的那一列数据
    auto blend = [&]
    (
      // 两个点的索引
      std::size_t a, std::size_t b,
      // 按照连续路径混合还是按照断开的路径混合
      bool continuous,
      // 第一个点占的比例
      double ratio,
      std::size_t resolution, std::array<double, 2> frequency_range
    ) -> std::vector<double>
    {
      // 混合得到的频率和权重
      std::vector<double> frequency, weight;
      // 如果是连续路径，将每个模式的频率和权重按照比例混合
      if (continuous)
      {
        assert(qpoints[a].ModeData.size() == qpoints[b].ModeData.size());
        for (std::size_t i = 0; i < qpoints[a].ModeData.size(); i++)
        {
          frequency.push_back
            (qpoints[a].ModeData[i].Frequency * ratio + qpoints[b].ModeData[i].Frequency * (1 - ratio));
          weight.push_back(qpoints[a].ModeData[i].Weight * ratio + qpoints[b].ModeData[i].Weight * (1 - ratio));
        }
      }
      // 如果是不连续路径，将每个模式的权重乘以比例，最后相加
      else
      {
        for (std::size_t i = 0; i < qpoints[a].ModeData.size(); i++)
        {
          frequency.push_back(qpoints[a].ModeData[i].Frequency);
          weight.push_back(qpoints[a].ModeData[i].Weight * ratio);
        }
        for (std::size_t i = 0; i < qpoints[b].ModeData.size(); i++)
        {
          frequency.push_back(qpoints[b].ModeData[i].Frequency);
          weight.push_back(qpoints[b].ModeData[i].Weight * (1 - ratio));
        }
      }
      std::vector<double> result(resolution);
      for (std::size_t i = 0; i < frequency.size(); i++)
      {
        std::ptrdiff_t index = (frequency[i] - frequency_range[0]) / (frequency_range[1] - frequency_range[0])
          * resolution;
        if (index >= 0 && index < static_cast<std::ptrdiff_t>(resolution)) result[index] += weight[i];
      }
      return result;
    };

    std::vector<std::vector<double>> values;
    for (std::size_t i = 0; i < resolution[0]; i++)
    {
      auto current_distance = total_distance * i / resolution[0];
      auto it = path.lower_bound(current_distance);
      if (it == path.begin()) values.push_back(blend
          (it->second, it->second, true, 1, resolution[1], frequency_range));
      else if (it == path.end()) values.push_back(blend
      (
        std::prev(it)->second, std::prev(it)->second, true, 1,
        resolution[1], frequency_range
      ));
      else values.push_back(blend
      (
        std::prev(it)->second, it->second, !path_begin.contains(it->second),
        (it->first - current_distance) / (it->first - std::prev(it)->first),
        resolution[1], frequency_range
      ));
    }
    return values;
  };

  // 根据数值, 画图
  auto plot = []
  (
    const std::vector<std::vector<double>>& values,
    const std::string& filename,
    const std::vector<double>& x_ticks, const std::vector<double>& y_ticks,
    const std::vector<std::string>& y_ticklabels,
    const std::optional<double>& aspect_ratio,
    const std::optional<std::array<std::size_t, 2>>& resolution
  )
  {
    std::vector<std::vector<double>>
      r(values[0].size(), std::vector<double>(values.size(), 0)),
      g(values[0].size(), std::vector<double>(values.size(), 0)),
      b(values[0].size(), std::vector<double>(values.size(), 0)),
      a(values[0].size(), std::vector<double>(values.size(), 0));
    for (std::size_t i = 0; i < values[0].size(); i++)
      for (std::size_t j = 0; j < values.size(); j++)
      {
        auto v = values[j][i];
        if (v < 0.05) v = 0;
        a[i][j] = v * 100 * 255;
        if (a[i][j] > 255) a[i][j] = 255;
        r[i][j] = 255 - v * 2 * 255;
        if (r[i][j] < 0) r[i][j] = 0;
        g[i][j] = 255 - v * 2 * 255;
        if (g[i][j] < 0) g[i][j] = 0;
        b[i][j] = 255;
      }
    auto f = matplot::figure(true);
    auto ax = f->current_axes();
    auto image = ax->image(std::tie(r, g, b));
    image->matrix_a(a);
    ax->y_axis().reverse(false);
    ax->x_axis().tick_values(x_ticks);
    ax->x_axis().tick_length(1);
    ax->x_axis().ticklabels(std::vector<std::string>(x_ticks.size()));
    ax->y_axis().tick_values(y_ticks);
    ax->y_axis().tick_length(1);
    ax->y_axis().ticklabels(y_ticklabels);
    if (aspect_ratio)
    {
      ax->axes_aspect_ratio_auto(false);
      ax->axes_aspect_ratio(*aspect_ratio);
    }
    if (resolution)
    {
      f->width((*resolution)[0]);
      f->height((*resolution)[1]);
    }
    f->save(filename, "png");
  };

  auto input = YAML::LoadFile(config_file).as<Input>();
  auto unfolded_data = biu::deserialize<UnfoldOutput>
    (biu::read<std::byte>(input.UnfoldedDataFile));
  
  // 搜索画图需要用到的 q 点
  // key 到起点的距离，value 为 q 点在 QpointData 中的索引
  boost::container::flat_map<double, std::size_t> path;
  // 每一条连续路径的第一个 q 点在 path 中的索引
  std::set<std::size_t> path_begin;
  // x 轴的刻度，为 path 中的索引
  std::set<std::size_t> x_ticks_index;
  double total_distance = 0;
  for (auto& line : input.Qpoints)
  {
    assert(line.size() >= 2);
    path_begin.insert(path.size());
    for (std::size_t i = 0; i < line.size() - 1; i++)
    {
      x_ticks_index.insert(path.size());
      auto [this_path, this_distance] = search_qpoints
      (
        unfolded_data.PrimativeCell, {line[i], line[i + 1]},
        unfolded_data.QpointData
          | ranges::views::transform(&UnfoldOutput::QpointDataType::Qpoint)
          | ranges::to_vector,
        input.ThresholdWhenSearchingQpoints.value_or(0.001),
        i != line.size() - 2
      );
      path.merge
      (
        this_path
        | ranges::views::transform([&](auto& p)
          { return std::make_pair(p.first + total_distance, p.second); })
        | ranges::to<boost::container::flat_map>
      );
      total_distance += this_distance;
    }
  }

  // 计算画图的数据
  auto values = calculate_values
  (
    path, path_begin, unfolded_data.QpointData, input.InterpolationResolution,
    input.FrequencyRange, total_distance
  );
  auto x_ticks = x_ticks_index | ranges::views::transform([&](auto i)
    { return path.nth(i)->first / total_distance * input.InterpolationResolution[0]; }) | ranges::to<std::vector>;
  auto y_ticks = input.YTicks.value_or(std::vector<std::pair<double, std::string>>{})
    | biu::toLvalue | ranges::views::keys
    | ranges::views::transform([&](auto i)
    {
      return (i - input.FrequencyRange[0]) / (input.FrequencyRange[1] - input.FrequencyRange[0])
        * input.InterpolationResolution[1];
    })
    | ranges::to_vector;
  auto y_ticklabels = input.YTicks.value_or(std::vector<std::pair<double, std::string>>{})
    | biu::toLvalue | ranges::views::values | ranges::to_vector;
  if (input.OutputPictureFile) plot
  (
    values, input.OutputPictureFile.value(),
    x_ticks, y_ticks, y_ticklabels, input.AspectRatio, input.PictureResolution
  );
  if (input.OutputDataFile)
    biu::Hdf5file(input.OutputDataFile.value(), true)
      .write("Values", values)
      .write("XTicks", x_ticks)
      .write("YTicks", y_ticks)
      .write("YTickLabels", y_ticklabels)
      .write("InterpolationResolution", input.InterpolationResolution)
      .write("FrequencyRange", input.FrequencyRange);
}

void ufo::plot_point(std::string config_file)
{
  struct Input
  {
    std::string UnfoldedDataFile;
    // 要画图的 q 点
    Eigen::Vector3d Qpoint;
    // 插值的分辨率
    std::size_t InterpolationResolution;
    std::optional<double> AspectRatio;
    std::optional<std::array<std::size_t, 2>> PictureResolution;
    // 画图的频率范围
    std::array<double, 2> FrequencyRange;
    // 搜索 q 点时的阈值，单位为埃^-1
    std::optional<double> ThresholdWhenSearchingQpoints;
    // 是否要在 z 轴上作一些标记
    std::optional<std::vector<std::pair<double, std::string>>> XTicks;
    // 是否输出图片
    std::optional<std::string> OutputPictureFile;
    // 是否输出数据，可以进一步使用 matplotlib 画图
    std::optional<std::string> OutputDataFile;
  };

  // 根据 q 点路径, 搜索要使用的 q 点，返回的是 q 点在 QpointData 中的索引
  auto search_qpoints = []
  (
    const Eigen::Matrix3d& primative_cell,
    const Eigen::Vector3d& qpoint, const std::vector<Eigen::Vector3d>& qpoints,
    double threshold
  )
  {
    biu::Logger::Guard log(qpoint);
    // 对于 output 中的每一个点, 检查这个点是否与所寻找的点足够近，如果足够近则返回
    for (std::size_t i = 0; i < qpoints.size(); i++)
      for (auto cell_shift
        : biu::sequence(Eigen::Vector3i(-1, -1, -1), Eigen::Vector3i(2, 2, 2)))
      {
        auto this_qpoint
          = (primative_cell.reverse().transpose() * (qpoints[i] + cell_shift.first.cast<double>())).eval();
        if ((this_qpoint - primative_cell.reverse().transpose() * qpoint).norm() < threshold) return log.rtn(i);
      }
    throw std::runtime_error("No q points found");
  };

  // 根据搜索到的 q 点, 计算图中每个点的值
  auto calculate_values = []
  (
    // q 点的数据（需要用到它的频率和权重）
    const UnfoldOutput::QpointDataType& qpoint,
    // 用于插值的分辨率和范围
    std::size_t resolution,
    const std::array<double, 2>& frequency_range
  )
  {
    biu::Logger::Guard log;
    std::vector<double> result(resolution);
    for (auto& mode : qpoint.ModeData)
    {
      double index_double = (mode.Frequency - frequency_range[0]) / (frequency_range[1] - frequency_range[0])
        * (resolution - 1);
      std::ptrdiff_t index = std::round(index_double);
      if (index >= 0 && index < static_cast<std::ptrdiff_t>(resolution)) result[index] += mode.Weight;
    }
    return log.rtn(result);
  };

  // 根据数值, 画图
  auto plot = []
  (
    const std::vector<double>& values, const std::string& filename,
    const std::vector<double>& x_ticks, const std::vector<std::string>& x_ticklabels,
    const std::optional<double>& aspect_ratio, const std::optional<std::array<std::size_t, 2>>& resolution
  )
  {
    biu::Logger::Guard log;
    auto f = matplot::figure(true);
    auto ax = f->current_axes();
    auto image = ax->plot(values);
    ax->y_axis().reverse(false);
    ax->x_axis().tick_values(x_ticks);
    ax->x_axis().tick_length(1);
    ax->x_axis().ticklabels(x_ticklabels);
    ax->y_axis().tick_values({});
    if (aspect_ratio)
    {
      ax->axes_aspect_ratio_auto(false);
      ax->axes_aspect_ratio(*aspect_ratio);
    }
    if (resolution)
    {
      f->width((*resolution)[0]);
      f->height((*resolution)[1]);
    }
    f->save(filename, "png");
  };

  biu::Logger::Guard log;
  auto input = YAML::LoadFile(config_file).as<Input>();
  auto unfolded_data = biu::deserialize<UnfoldOutput>
    (biu::read<std::byte>(input.UnfoldedDataFile));
  
  auto qpoint_index = search_qpoints
  (
    unfolded_data.PrimativeCell, input.Qpoint,
    unfolded_data.QpointData
      | ranges::views::transform(&UnfoldOutput::QpointDataType::Qpoint)
      | ranges::to_vector,
    input.ThresholdWhenSearchingQpoints.value_or(0.001)
  );
  auto values = calculate_values
  (
    unfolded_data.QpointData[qpoint_index],
    input.InterpolationResolution, input.FrequencyRange
  );
  auto x_ticks = input.XTicks.value_or(std::vector<std::pair<double, std::string>>{})
    | biu::toLvalue | ranges::views::keys
    | ranges::views::transform([&](auto i)
    {
      return (i - input.FrequencyRange[0]) / (input.FrequencyRange[1] - input.FrequencyRange[0])
        * input.InterpolationResolution;
    })
    | ranges::to_vector;
  auto x_ticklabels = input.XTicks.value_or(std::vector<std::pair<double, std::string>>{})
    | biu::toLvalue | ranges::views::values | ranges::to_vector;
  if (input.OutputPictureFile) plot
  (
    values, input.OutputPictureFile.value(),
    x_ticks, x_ticklabels, input.AspectRatio, input.PictureResolution
  );
  if (input.OutputDataFile)
    biu::Hdf5file(input.OutputDataFile.value(), true)
      .write("Values", values)
      .write("XTicks", x_ticks)
      .write("XTickLabels", x_ticklabels)
      .write("InterpolationResolution", input.InterpolationResolution)
      .write("FrequencyRange", input.FrequencyRange);
}
