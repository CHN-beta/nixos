# include <sbatch-tui.hpp>

namespace sbatch
{
  class Fdtd : public Program
  {
    public: struct StateType
    {
      int QueueSelected = 0;
      std::vector<std::string> QueueEntries;
      int CpuSchemeSelected = 0;
      std::vector<std::string> CpuSchemeEntries = { "Default", "Custom" };
      std::string Cpus = "1";
      bool Nomultithread = true;
      int MemorySchemeSelected = 0;
      std::vector<std::string> MemorySchemeEntries = { "Default", "All", "Custom" };
      std::string Memory = "1";
      std::string InputFile = "main.fsp";
    };
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
        if (saved_state.CpuSchemeSelected < State_.CpuSchemeEntries.size())
          State_.CpuSchemeSelected = saved_state.CpuSchemeSelected;
        State_.Cpus = saved_state.Cpus;
        State_.Nomultithread = saved_state.Nomultithread;
        if (saved_state.MemorySchemeSelected < State_.MemorySchemeEntries.size())
          State_.MemorySchemeSelected = saved_state.MemorySchemeSelected;
        State_.Memory = saved_state.Memory;
        State_.InputFile = saved_state.InputFile;
      }
      catch (...) {}
    }
    public: virtual YAML::Node save_state() const override { return YAML::Node(State_); }
    public: virtual ftxui::Component get_interface() override
    {
      return ftxui::Container::Vertical
      ({
        // 第一行：选择队列和配置
        ftxui::Container::Horizontal
        ({
          // 队列
          ftxui::Menu(&State_.QueueEntries, &State_.QueueSelected)
            | with_title("Queue:", ftxui::Color::GrayDark),
          // CPU 设置
          ftxui::Container::Horizontal
          ({
            ftxui::Menu(&State_.CpuSchemeEntries, &State_.CpuSchemeSelected),
            ftxui::Container::Vertical
            ({
              input(&State_.Cpus, "CPU: "),
              checkbox("Disable multithread", &State_.Nomultithread)
            })
              | with_list_padding | with_separator
              | ftxui::Maybe([&]{ return State_.CpuSchemeSelected == 1; })
          }) | with_title("CPU:", ftxui::Color::GrayDark) | with_separator,
          // 内存
          ftxui::Container::Horizontal
          ({
            ftxui::Menu(&State_.MemorySchemeEntries, &State_.MemorySchemeSelected),
            input(&State_.Memory, "Memory (GB): ")
              | with_list_padding | with_separator
              | ftxui::Maybe([&]{ return State_.MemorySchemeSelected == 2; })
          }) | with_title("Memory:", ftxui::Color::GrayDark) | with_separator
        }) | with_title("Resource allocation:") | with_bottom,
        // 第二行：输入文件
        ftxui::Container::Vertical({input(&State_.InputFile, "Input file: ")})
          | with_title("Misc:")
      });
    }
    public: virtual std::string get_submit_command() const override
    {
      auto recommended = Recommendeds_[State_.QueueSelected];
      auto cpu_string = [&]
      {
        if (State_.CpuSchemeSelected == 0)
          return "--ntasks={} --cpus-per-task=1 --hint=nomultithread"_f(recommended.Cpus);
        else if (State_.CpuSchemeSelected == 1) return "--ntasks={} --cpus-per-task=1{}"_f
          (State_.Cpus, State_.Nomultithread ? " --hint=nomultithread" : "");
        else std::unreachable();
      }();
      auto mem_string = [&]
      {
        if (State_.MemorySchemeSelected == 0) return recommended.Memory ? " --mem={}G"_f(recommended.Memory) : "";
        else if (State_.MemorySchemeSelected == 1) return " --mem=0"s;
        else if (State_.MemorySchemeSelected == 2) return " --mem={}G"_f(State_.Memory);
        else std::unreachable();
      }();
      auto srun_string = [&]
      {
        if (State_.CpuSchemeSelected == 0 && recommended.Cpus)
          return " --ntasks={} --cpus-per-task={}"_f(recommended.Mpi, recommended.Openmp);
        else return ""s;
      }();
      return
        "{}sbatch --partition={} --nodes=1-1\n{}{}\n"
          "--wrap=\"srun{} vasp-intel vasp-{}\""_f
        (
          optcell_string, State_.QueueEntries[State_.QueueSelected], cpu_string, mem_string,
          srun_string, State_.VaspEntries[State_.VaspSelected]
        );
    }
  };
  template void Program::register_child_<VaspCpu>();
}
