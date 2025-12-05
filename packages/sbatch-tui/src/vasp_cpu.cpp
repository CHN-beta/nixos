# include <sbatch-tui.hpp>

namespace sbatch
{
  class VaspCpu : public Program
  {
    public: struct StateType
    {
      int VaspSelected = 0;
      std::vector<std::string> VaspEntries = { "std", "gam", "ncl" };
      int QueueSelected = 0;
      std::vector<std::string> QueueEntries;
      int CpuSchemeSelected = 0;
      std::vector<std::string> CpuSchemeEntries = { "Default", "Custom" };
      std::string MpiThreads = "1";
      std::string OpenmpThreads = "1";
      bool Nomultithread = true;
      int MemorySchemeSelected = 0;
      std::vector<std::string> MemorySchemeEntries = { "Default", "Custom" };
      std::string Memory = "1";
      bool OptcellEnable = false;
      int OptcellSelected = 0;
      std::vector<std::string> OptcellEntries = { "fix ab", "fix c" };
    };
    protected: StateType State_;
    protected: struct Recommended_ { int Mpi, Openmp; std::optional<int> Memory, Cpus; };
    protected: std::vector<Recommended_> Recommendeds_;
    public: virtual std::string get_name() const override { return "VASP(CPU)"; }
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
        if (saved_state.VaspSelected < State_.VaspEntries.size()) State_.VaspSelected = saved_state.VaspSelected;
        if (saved_state.QueueSelected < State_.QueueEntries.size()) State_.QueueSelected = saved_state.QueueSelected;
        if (saved_state.CpuSchemeSelected < State_.CpuSchemeEntries.size())
          State_.CpuSchemeSelected = saved_state.CpuSchemeSelected;
        State_.OpenmpThreads = saved_state.OpenmpThreads;
        State_.MpiThreads = saved_state.MpiThreads;
        State_.Nomultithread = saved_state.Nomultithread;
        if (saved_state.MemorySchemeSelected < State_.MemorySchemeEntries.size())
          State_.MemorySchemeSelected = saved_state.MemorySchemeSelected;
        State_.Memory = saved_state.Memory;
        State_.OptcellEnable = saved_state.OptcellEnable;
        if (saved_state.OptcellSelected < State_.OptcellEntries.size())
          State_.OptcellSelected = saved_state.OptcellSelected;
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
          // CPU 设置
          ftxui::Container::Horizontal
          ({
            ftxui::Menu(&State_.CpuSchemeEntries, &State_.CpuSchemeSelected),
            ftxui::Container::Vertical
            ({
              input(&State_.MpiThreads, "MPI: "),
              input(&State_.OpenmpThreads, "OpenMP: "),
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
              | ftxui::Maybe([&]{ return State_.MemorySchemeSelected == 1; })
          }) | with_title("Memory:", ftxui::Color::GrayDark) | with_separator
        }) | with_title("Resource allocation:") | with_bottom,
        // 第三行：任务名和输出文件
        ftxui::Container::Vertical
        ({

          ftxui::Container::Horizontal
          ({
            checkbox("Generate OPTCELL", &State_.OptcellEnable),
            ftxui::Menu(&State_.OptcellEntries, &State_.OptcellSelected)
              | with_separator | ftxui::Maybe([&]{ return State_.OptcellEnable; })
          })
        }) | with_title("Misc:")
      });
    }
    public: virtual std::vector<std::string> get_submit_command(std::string extra_sbatch_parameter) const override
    {
      auto optcell_string = [&]
      {
        if (State_.OptcellEnable)
          if (State_.OptcellSelected == 0) return "echo -e '000\\n000\\n001' > OPTCELL &&"s;
          else if (State_.OptcellSelected == 1) return "echo -e '110\\n110\\n000' > OPTCELL &&"s;
          else std::unreachable();
        else return ""s;
      }();
      auto recommended = Recommendeds_[State_.QueueSelected];
      auto cpu_string = [&]
      {
        if (State_.CpuSchemeSelected == 0)
          if (recommended.Cpus) return "--ntasks={} --cpus-per-task=1 --hint=nomultithread"_f(*recommended.Cpus);
          else return "--ntasks={} --cpus-per-task={} --hint=nomultithread"_f(recommended.Mpi, recommended.Openmp);
        else if (State_.CpuSchemeSelected == 1) return "--ntasks={} --cpus-per-task={}{}"_f
          (State_.MpiThreads, State_.OpenmpThreads, State_.Nomultithread ? " --hint=nomultithread" : "");
        else std::unreachable();
      }();
      auto mem_string = [&]
      {
        if (State_.MemorySchemeSelected == 0) return recommended.Memory ? "--mem={}G"_f(*recommended.Memory) : "";
        else if (State_.MemorySchemeSelected == 1) return "--mem={}G"_f(State_.Memory);
        else std::unreachable();
      }();
      auto srun_string = [&]
      {
        if (State_.CpuSchemeSelected == 0 && recommended.Cpus)
          return " --ntasks={} --cpus-per-task={}"_f(recommended.Mpi, recommended.Openmp);
        else return ""s;
      }();
      return
      {
        optcell_string,
        "sbatch"s,
        "--partition={} --nodes=1-1"_f(State_.QueueEntries[State_.QueueSelected]),
        cpu_string, mem_string,
        "--wrap=\"srun{} vasp-intel vasp-{}\""_f(srun_string, State_.VaspEntries[State_.VaspSelected]),
        extra_sbatch_parameter
      };
    }
  };
  template void Program::register_child_<VaspCpu>();
}
