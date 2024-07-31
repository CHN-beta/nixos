# include <ufo/solver.hpp>

namespace ufo
{
  concurrencpp::generator<std::pair<Eigen::Vector<unsigned, 3>, unsigned>> Solver::triplet_sequence
    (Eigen::Vector<unsigned, 3> range)
  {
    for (unsigned x = 0; x < range[0]; x++)
      for (unsigned y = 0; y < range[1]; y++)
        for (unsigned z = 0; z < range[2]; z++)
          co_yield
          {
            Eigen::Vector<unsigned, 3>{{x}, {y}, {z}},
            x * range[1] * range[2] + y * range[2] + z
          };
  }

  Solver::DataFile::DataFile
    (YAML::Node node, std::set<std::string> supported_format, std::string config_file, bool allow_same_as_config_file)
  {
    if (auto _ = node["SameAsConfigFile"])
    {
      auto __ = _.as<bool>();
      if (__ && !allow_same_as_config_file)
        throw std::runtime_error("\"SameAsConfigFile: true\" is not allowed here.");
      ExtraParameters["SameAsConfigFile"] = __;
      if (__)
      {
        Filename = config_file;
        Format = "yaml";
        return;
      }
    }
    Filename = node["Filename"].as<std::string>();
    Format = node["Format"].as<std::string>();
    if (!supported_format.contains(Format))
      throw std::runtime_error(fmt::format("Unsupported format: \"{}\"", Format));
    if (auto _ = node["RelativeToConfigFile"])
    {
      auto __ = _.as<bool>();
      ExtraParameters["RelativeToConfigFile"] = __;
      if (__)
        Filename = std::filesystem::path(config_file).parent_path() / Filename;
    }
  };

}
