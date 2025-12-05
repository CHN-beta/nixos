# include <sbatch-tui.hpp>

namespace sbatch
{
  class Mumax3 : public Program
  {
    public: struct StateType
    {
      int QueueSelected = 0;
      std::vector<std::string> QueueEntries;
      int GpuSchemeSelected = 0;
      std::vector<std::string> GpuSchemeEntries = { "Any", "Custom" };
      std::vector<int> GpuSelected;
      std::vector<std::vector<std::string>> GpuEntries;
      bool Nomultithread = true;
      int MemorySchemeSelected = 0;
      std::vector<std::string> MemorySchemeEntries = { "Default", "Custom" };
      std::string Memory = "1";
      std::string InputFile = "input.txt";
    };
    protected: StateType State_;
    public: virtual std::string get_name() const override { return "Mumax3"; }
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
        if (saved_state.QueueSelected < State_.QueueEntries.size()) State_.QueueSelected = saved_state.QueueSelected;
        if (saved_state.GpuSchemeSelected < State_.GpuSchemeEntries.size())
          State_.GpuSchemeSelected = saved_state.GpuSchemeSelected;
        if (saved_state.GpuSelected.size() == State_.GpuSelected.size())
          for (size_t i = 0; i < State_.GpuSelected.size(); i++)
            if (saved_state.GpuSelected[i] < State_.GpuEntries[i].size())
              State_.GpuSelected[i] = saved_state.GpuSelected[i];
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
        // 第一行
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
          }) | with_title("GPU:", ftxui::Color::GrayDark) | with_separator,
          // CPU 设置
          checkbox("Disable multithread", &State_.Nomultithread)
            | with_title("CPU:", ftxui::Color::GrayDark) | with_separator,
          // 内存
          ftxui::Container::Horizontal
          ({
            ftxui::Menu(&State_.MemorySchemeEntries, &State_.MemorySchemeSelected),
            input(&State_.Memory, "Memory (GB): ")
              | with_list_padding | with_separator
              | ftxui::Maybe([&]{ return State_.MemorySchemeSelected == 1; })
          }) | with_title("Memory:", ftxui::Color::GrayDark) | with_separator
        }) | with_title("Resource allocation:") | with_bottom,
        // 第三行：任务名和输入输出文件
        ftxui::Container::Vertical({input(&State_.InputFile, "Input file: ")})
          | with_title("Misc:")
      });
    }
    public: virtual std::vector<std::string> get_submit_command(std::string extra_sbatch_parameter) const override
    {
      auto cpu_string = [&]
        { return State_.Nomultithread ? "--hint=nomultithread" : ""; }();
      auto gpu_string = [&]
      {
        if (State_.GpuSchemeSelected == 0) return "--gpus=1"s;
        else if (State_.GpuSchemeSelected == 1) return "--gpus={}:1"_f
          (State_.GpuEntries[State_.QueueSelected][State_.GpuSelected[State_.QueueSelected]]);
        else std::unreachable();
      }();
      auto mem_string = [&]
      {
        if (State_.MemorySchemeSelected == 0) return "--mem=32G"s;
        else if (State_.MemorySchemeSelected == 1) return "--mem={}G"_f(State_.Memory);
        else std::unreachable();
      }();
      return
      {
        "sbatch"s,
        "--partition={}"_f(State_.QueueEntries[State_.QueueSelected]),
        gpu_string, cpu_string, mem_string,
        "--wrap=\"mumax3 {}\""_f(escape(escape(State_.InputFile))),
        extra_sbatch_parameter
      };
    }
  };
  template void Program::register_child_<Mumax3>();
}
