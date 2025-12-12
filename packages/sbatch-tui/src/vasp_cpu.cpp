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
        }) | with_title("Resource allocation:") | with_bottom
      });
    }
    public: virtual std::vector<std::string> get_submit_command(std::string extra_sbatch_parameter) const override
    {
      auto recommended = Recommendeds_[State_.QueueSelected];
      auto cpu_string = recommended.Cpus ? "--ntasks={} --cpus-per-task=1 --hint=nomultithread"_f(*recommended.Cpus)
        : "--ntasks={} --cpus-per-task={} --hint=nomultithread"_f(recommended.Mpi, recommended.Openmp);
      auto mem_string = recommended.Memory ? "--mem={}G"_f(*recommended.Memory) : "";
      auto srun_string =
        recommended.Cpus ? " --ntasks={} --cpus-per-task={}"_f(recommended.Mpi, recommended.Openmp) : ""s;
      return
      {
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
