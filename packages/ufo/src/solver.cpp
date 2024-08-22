# include <ufo/solver.hpp>

namespace ufo
{
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
      throw std::runtime_error("Unsupported format: \"{}\""_f(Format));
    if (auto _ = node["RelativeToConfigFile"])
    {
      auto __ = _.as<bool>();
      ExtraParameters["RelativeToConfigFile"] = __;
      if (__)
        Filename = std::filesystem::path(config_file).parent_path() / Filename;
    }
  };

}
