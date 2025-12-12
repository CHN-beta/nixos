# include <sbatch-tui.hpp>

namespace sbatch
{
  class Fdtd : public Program
  {
    public: struct StateType
      { int QueueSelected = 0; std::vector<std::string> QueueEntries; std::string InputFile = "input.fsp"; };
    protected: StateType State_;
    protected: struct Recommended_ { int Cpus; std::optional<int> Memory; };
    protected: std::vector<Recommended_> Recommendeds_;
    public: virtual std::string get_name() const override { return "Lumerical FDTD"; }
    public: virtual void load_config(YAML::Node node) override
    {
      for (auto queue : node["Queue"])
      {
        State_.QueueEntries.push_back(queue["Name"].as<std::string>());
        Recommendeds_.push_back(queue["Recommended"].as<Recommended_>());
      }
    }
    public: virtual void try_load_state(YAML::Node node) noexcept override
    {
      try
      {
        auto saved_state = node.as<decltype(State_)>();
        if (saved_state.QueueSelected < State_.QueueEntries.size()) State_.QueueSelected = saved_state.QueueSelected;
        State_.InputFile = saved_state.InputFile;
      }
      catch (...) {}
    }
    public: virtual YAML::Node save_state() const override { return YAML::Node(State_); }
    public: virtual ftxui::Component get_interface() override
    {
      return ftxui::Container::Vertical
      ({
        // 第一行
        ftxui::Container::Horizontal
        ({
          ftxui::Menu(&State_.QueueEntries, &State_.QueueSelected) | with_title("Queue:", ftxui::Color::GrayDark)
        }) | with_title("Resource allocation:") | with_bottom,
        // 第三行：输入文件
        ftxui::Container::Vertical({input(&State_.InputFile, "Input file: ")}) | with_title("Misc:")
      });
    }
    public: virtual std::vector<std::string> get_submit_command(std::string extra_sbatch_parameter) const override
    {
      auto recommended = Recommendeds_[State_.QueueSelected];
      auto cpu_string = "--ntasks={} --cpus-per-task=1 --hint=nomultithread"_f(recommended.Cpus);
      auto mem_string = recommended.Memory ? "--mem={}G"_f(*recommended.Memory) : "";
      return
      {
        "sbatch"s,
        "--partition={} --nodes=1-1"_f(State_.QueueEntries[State_.QueueSelected]),
        cpu_string, mem_string, "--export=ALL,ANSYSLMD_LICENSE_FILE=1055@127.0.0.1",
        "--wrap=\"lumerical srun fdtd-engine-ompi-lcl {}\""_f(escape(State_.InputFile)),
        extra_sbatch_parameter
      };
    }
  };
  template void Program::register_child_<Fdtd>();
}
