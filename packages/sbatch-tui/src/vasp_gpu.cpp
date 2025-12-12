# include <sbatch-tui.hpp>

namespace sbatch
{
  class VaspGpu : public Program
  {
    public: struct StateType
    {
      int VaspSelected = 0;
      std::vector<std::string> VaspEntries = { "std", "gam", "ncl" };
      int QueueSelected = 0;
      std::vector<std::string> QueueEntries;
      int GpuSchemeSelected = 0;
      std::vector<std::string> GpuSchemeEntries = { "Any", "Custom" };
      std::vector<int> GpuSelected;
      std::vector<std::vector<std::string>> GpuEntries;
    };
    protected: StateType State_;
    public: virtual std::string get_name() const override { return "VASP(GPU)"; }
    public: virtual void load_config(YAML::Node node) override
    {
      for (auto queue : node["Queue"])
      {
        State_.QueueEntries.push_back(queue["Name"].as<std::string>());
        State_.GpuSelected.push_back(0);
        State_.GpuEntries.push_back(queue["Gpu"].as<std::vector<std::string>>());
      }
    }
    public: virtual void try_load_state(YAML::Node node) noexcept override
    {
      try
      {
        auto saved_state = node.as<decltype(State_)>();
        if (saved_state.VaspSelected < State_.VaspEntries.size()) State_.VaspSelected = saved_state.VaspSelected;
        if (saved_state.QueueSelected < State_.QueueEntries.size()) State_.QueueSelected = saved_state.QueueSelected;
        if (saved_state.GpuSchemeSelected < State_.GpuSchemeEntries.size())
          State_.GpuSchemeSelected = saved_state.GpuSchemeSelected;
        if (saved_state.GpuSelected.size() == State_.GpuSelected.size())
          for (size_t i = 0; i < State_.GpuSelected.size(); i++)
            if (saved_state.GpuSelected[i] < State_.GpuEntries[i].size())
              State_.GpuSelected[i] = saved_state.GpuSelected[i];
      }
      catch (...) {}
    }
    public: virtual YAML::Node save_state() const override { return YAML::Node(State_); }
    public: virtual ftxui::Component get_interface() override
    {
      return ftxui::Container::Vertical
      ({
        // 第一行：选择程序
        ftxui::Menu(&State_.VaspEntries, &State_.VaspSelected)
          | with_title("VASP variant:") | with_bottom,
        // 第二行
        ftxui::Container::Horizontal
        ({
          // 队列
          ftxui::Menu(&State_.QueueEntries, &State_.QueueSelected)
            | with_title("Queue:", ftxui::Color::GrayDark),
          // GPU 设置，默认还是手动设置，如果手动的话，选定 GPU
          ftxui::Container::Horizontal
          ({
            ftxui::Menu(&State_.GpuSchemeEntries, &State_.GpuSchemeSelected),
            ftxui::Container::Tab
            (
              ranges::views::iota(0zu, State_.GpuEntries.size())
                | ranges::views::transform([&](auto i)
                  { return ftxui::Menu(&State_.GpuEntries[i], &State_.GpuSelected[i]); })
                | ranges::to_vector,
              &State_.QueueSelected
            ) | with_list_padding | with_separator
              | ftxui::Maybe([&]{ return State_.GpuSchemeSelected == 1; })
          }) | with_title("GPU:", ftxui::Color::GrayDark) | with_separator
        }) | with_title("Resource allocation:") | with_bottom
      });
    }
    public: virtual std::vector<std::string> get_submit_command(std::string extra_sbatch_parameter) const override
    {
      auto cpu_string = "--ntasks=1 --cpus-per-task=1 --hint=nomultithread"s;
      auto gpu_string = [&]
      {
        if (State_.GpuSchemeSelected == 0) return "--gpus=1"s;
        else if (State_.GpuSchemeSelected == 1) return "--gpus={}:1"_f
          (State_.GpuEntries[State_.QueueSelected][State_.GpuSelected[State_.QueueSelected]]);
        else std::unreachable();
      }();
      auto mem_string = "--mem=32G"s;
      return
      {
        "sbatch"s,
        "--partition={} --nodes=1-1"_f(State_.QueueEntries[State_.QueueSelected]),
        gpu_string, cpu_string, mem_string,
        "--wrap=\"srun vasp-nvidia vasp-{}\""_f(State_.VaspEntries[State_.VaspSelected]),
        extra_sbatch_parameter
      };
    }
  };
  template void Program::register_child_<VaspGpu>();
}
