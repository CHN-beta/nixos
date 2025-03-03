# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/algorithm/string.hpp>
# include <biu.hpp>

# ifndef SBATCH_CONFIG
#   define SBATCH_CONFIG "./sbatch-tui.yaml"
# endif

int main()
{
  using namespace biu::literals;

  struct Device
  {
    struct CpuQueueType { int CpuMpiThreads, CpuOpenmpThreads; std::optional<int> MemoryGB, AllocateCpus; };
    std::vector<std::pair<std::string, CpuQueueType>> CpuQueues;
    struct GpuQueueType { std::vector<std::string> GpuIds; };
    std::optional<std::vector<std::pair<std::string, GpuQueueType>>> GpuQueues;
  };
  auto device = YAML::LoadFile(SBATCH_CONFIG).as<Device>();

  // 需要绑定到界面上的变量
  struct
  {
    // 第一行，要选择的程序
    int program_selected = 0;
    std::vector<std::string> program_entries; // 稍后初始化
    int vasp_selected = 0;
    std::vector<std::string> vasp_entries = { "std", "gam", "ncl" };

    // 第二行，如果是CPU，要选择的队列，和队列的参数
    int cpu_queue_selected = 0;
    std::vector<std::string> cpu_queue_entries; // 稍后初始化
    int cpu_cpu_scheme_selected = 0;
    std::vector<std::string> cpu_cpu_scheme_entries = { "Default", "Custom" };
    std::string cpu_mpi_threads = "1";
    std::string cpu_openmp_threads = "1";
    bool cpu_cpu_nomultithread = true;
    int cpu_memory_scheme_selected = 0;
    std::vector<std::string> cpu_memory_scheme_entries = { "Default", "All", "Custom" };
    std::string cpu_memory = "1";

    // 第二行，如果是GPU，要选择的队列
    int gpu_queue_selected = 0;
    std::vector<std::string> gpu_queue_entries; // 稍后初始化
    int gpu_gpu_scheme_selected = 0;
    std::vector<std::string> gpu_gpu_scheme_entries = { "Any", "Custom" };
    std::vector<int> gpu_gpu_selected; // 稍后初始化
    std::vector<std::vector<std::string>> gpu_gpu_entries; // 稍后初始化
    int gpu_cpu_scheme_selected = 0;
    std::vector<std::string> gpu_cpu_scheme_entries = { "Default", "Custom" };
    std::string gpu_openmp_threads = "1";
    bool gpu_cpu_nomultithread = true;
    int gpu_memory_scheme_selected = 0;
    std::vector<std::string> gpu_memory_scheme_entries = { "Default", "All", "Custom" };
    std::string gpu_memory = "1";

    // 第三行，任务名和输出文件
    std::string job_name = std::filesystem::current_path().filename().string();
    std::string output_file = "output.txt";
    bool optcell_enable = false;
    int optcell_selected = 0;
    std::vector<std::string> optcell_entries = { "fix ab", "fix c" };

    // 用户选定的操作
    std::string user_command;

    // 生成的提交命令
    std::string submit_command;
  } state;
  {
    if (device.GpuQueues)
    {
      state.program_entries.push_back("VASP(GPU)");
      state.gpu_queue_entries = *device.GpuQueues | ranges::views::keys | ranges::to_vector;
      state.gpu_gpu_selected = std::vector<int>(state.gpu_queue_entries.size(), 0);
      state.gpu_gpu_entries = *device.GpuQueues | ranges::views::values
        | ranges::views::transform([](auto &x){ return x.GpuIds; }) | ranges::to_vector;
    }
    state.program_entries.push_back("VASP(CPU)");
    state.cpu_queue_entries = device.CpuQueues | ranges::views::keys | ranges::to_vector;
  }

  // 尝试从配置文件中读取设置
  try
  {
    auto config = YAML::LoadFile("{}/.config/sbatch-tui/config.yaml"_f(getenv("HOME")));
    auto saved_state = config.as<decltype(state)>();
    // 比较时会提升到 unsigned，所以不需要额外判断是否小于 0
    if (saved_state.program_selected < state.program_entries.size())
      state.program_selected = saved_state.program_selected;
    if (saved_state.vasp_selected < state.vasp_entries.size())
      state.vasp_selected = saved_state.vasp_selected;
    if (saved_state.cpu_queue_selected < state.cpu_queue_entries.size())
      state.cpu_queue_selected = saved_state.cpu_queue_selected;
    if (saved_state.cpu_cpu_scheme_selected < state.cpu_cpu_scheme_entries.size())
      state.cpu_cpu_scheme_selected = saved_state.cpu_cpu_scheme_selected;
    if (saved_state.cpu_memory_scheme_selected < state.cpu_memory_scheme_entries.size())
      state.cpu_memory_scheme_selected = saved_state.cpu_memory_scheme_selected;
    if (saved_state.gpu_queue_selected < state.gpu_queue_entries.size())
      state.gpu_queue_selected = saved_state.gpu_queue_selected;
    if (saved_state.gpu_gpu_scheme_selected < state.gpu_gpu_scheme_entries.size())
      state.gpu_gpu_scheme_selected = saved_state.gpu_gpu_scheme_selected;
    if (saved_state.gpu_gpu_selected.size() == state.gpu_gpu_selected.size())
      for (size_t i = 0; i < state.gpu_gpu_selected.size(); ++i)
        if (saved_state.gpu_gpu_selected[i] < state.gpu_gpu_entries[i].size())
          state.gpu_gpu_selected[i] = saved_state.gpu_gpu_selected[i];
    state.cpu_mpi_threads = saved_state.cpu_mpi_threads;
    state.cpu_openmp_threads = saved_state.cpu_openmp_threads;
    state.cpu_memory = saved_state.cpu_memory;
    state.cpu_cpu_nomultithread = saved_state.cpu_cpu_nomultithread;
    state.gpu_openmp_threads = saved_state.gpu_openmp_threads;
    state.gpu_memory = saved_state.gpu_memory;
    state.gpu_cpu_nomultithread = saved_state.gpu_cpu_nomultithread;
    state.optcell_enable = saved_state.optcell_enable;
    if (saved_state.optcell_selected < state.optcell_entries.size())
      state.optcell_selected = saved_state.optcell_selected;
  }
  catch (...) {}

  // 为组件增加标题栏
  auto with_title = [](std::string title, ftxui::Color bgcolor = ftxui::Color::Blue)
  {
    return [=](ftxui::Element element)
      { return ftxui::vbox(ftxui::text(title) | ftxui::bgcolor(bgcolor), element); };
  };
  // 为组件增加下边框
  auto with_bottom = [](ftxui::Element element) -> ftxui::Element
    { return ftxui::vbox(element, ftxui::separatorLight()); };
  // 为组件增加比较粗的下边框
  auto with_bottom_heavy = [](ftxui::Element element) -> ftxui::Element
    { return ftxui::vbox(element, ftxui::separatorHeavy()); };
  // 为组件增加空白以填充界面
  auto with_padding = [](ftxui::Element element) -> ftxui::Element
  {
    auto empty = ftxui::emptyElement() | ftxui::flex_grow;
    return ftxui::vbox(empty, ftxui::hbox(empty, element | ftxui::center, empty), empty);
  };
  // 为纵向列表自动增加空行，有 input 时使用，避免 input 被拉伸成多行
  auto with_list_padding = [](ftxui::Element element) -> ftxui::Element
    { return ftxui::vbox(element, ftxui::emptyElement() | ftxui::flex_grow); };
  // 在组件左边增加分割线
  auto with_separator = [](ftxui::Element element)
    { return ftxui::hbox(ftxui::separatorLight(), element); };
  // 在组件左边增加小标题
  auto with_subtitle = [](std::string title)
    { return [title](ftxui::Element element) { return ftxui::hbox(ftxui::text(title), element); }; };
  // 带标题的文本输入框
  auto input = [&](std::string* content, std::string title)
  {
    return ftxui::Input(content) | ftxui::underlined
      | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
      | ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 1)
      | with_subtitle(title);
  };
  // 在 putty 上可以正常显示的 checkbox (把勾选框换成 [x])
  auto checkbox = [&](std::string title, bool* checked)
  {
    auto checkbox_option = ftxui::CheckboxOption::Simple();
    checkbox_option.transform = [](const ftxui::EntryState& s)
    {
      auto prefix = ftxui::text(s.state ? "[X] " : "[ ] ");
      auto t = ftxui::text(s.label);
      if (s.active) t |= ftxui::bold;
      if (s.focused) t |= ftxui::inverted;
      return ftxui::hbox({prefix, t});
    };
    return ftxui::Checkbox(title, checked, checkbox_option);
  };

  // 构建界面
  auto screen = ftxui::ScreenInteractive::Fullscreen();
  // 捕获按键事件
  auto key_event_handler = [&](ftxui::Event event)
  {
    if (event == ftxui::Event::Return) state.user_command = "continue";
    else if (event == ftxui::Event::Escape) state.user_command = "quit";
    else return false;
    screen.ExitLoopClosure()();
    return true;
  };
  auto request_interface = ftxui::Container::Vertical
  ({
    // 第一行：选择程序
    ftxui::Container::Horizontal
    ({
      // 左侧：选择程序
      ftxui::Menu(&state.program_entries, &state.program_selected),
      // 右侧：选择 VASP 版本
      ftxui::Menu(&state.vasp_entries, &state.vasp_selected) | with_separator
    }) | with_title("Program:") | with_bottom,
    // 第二行
    ftxui::Container::Horizontal
    ({
      // 如果是选择 CPU 程序
      ftxui::Container::Horizontal
      ({
        // 选择队列
        ftxui::Menu(&state.cpu_queue_entries, &state.cpu_queue_selected)
          | with_title("Queue:", ftxui::Color::GrayDark),
        // CPU 设置，默认还是手动设置，如果手动的话，输入 MPI 和 OpenMP 线程数
        ftxui::Container::Horizontal
        ({
          ftxui::Menu(&state.cpu_cpu_scheme_entries, &state.cpu_cpu_scheme_selected),
          ftxui::Container::Vertical
          ({
            input(&state.cpu_mpi_threads, "MPI: "),
            input(&state.cpu_openmp_threads, "OpenMP: "),
            checkbox("Disable multithread", &state.cpu_cpu_nomultithread)
          })
            | with_list_padding | with_separator
            | ftxui::Maybe([&]{ return state.cpu_cpu_scheme_selected == 1; })
        }) | with_title("CPU:", ftxui::Color::GrayDark) | with_separator,
        // 内存
        ftxui::Container::Horizontal
        ({
          ftxui::Menu(&state.cpu_memory_scheme_entries, &state.cpu_memory_scheme_selected),
          input(&state.cpu_memory, "Memory (GB): ")
            | with_list_padding | with_separator
            | ftxui::Maybe([&]{ return state.cpu_memory_scheme_selected == 2; })
        }) | with_title("Memory:", ftxui::Color::GrayDark) | with_separator
      }) | ftxui::Maybe([&]{ return state.program_entries[state.program_selected] == "VASP(CPU)"; }),
      // 如果是选择 GPU 程序
      ftxui::Container::Horizontal
      ({
        // 队列
        ftxui::Menu(&state.gpu_queue_entries, &state.gpu_queue_selected)
          | with_title("Queue:", ftxui::Color::GrayDark),
        // GPU 设置，默认还是手动设置，如果手动的话，选定 GPU
        ftxui::Container::Horizontal
        ({
          ftxui::Menu(&state.gpu_gpu_scheme_entries, &state.gpu_gpu_scheme_selected),
          ftxui::Container::Tab
          (
            ranges::views::iota(0zu, state.gpu_gpu_entries.size())
              | ranges::views::transform([&](auto i)
                { return ftxui::Menu(&state.gpu_gpu_entries[i], &state.gpu_gpu_selected[i]); })
              | ranges::to_vector,
            &state.gpu_queue_selected
          ) | with_list_padding | with_separator
            | ftxui::Maybe([&]{ return state.gpu_gpu_scheme_selected == 1; })
        }) | with_title("GPU:", ftxui::Color::GrayDark) | with_separator,
        // CPU 设置
        ftxui::Container::Horizontal
        ({
          ftxui::Menu(&state.gpu_cpu_scheme_entries, &state.gpu_cpu_scheme_selected),
          ftxui::Container::Vertical
          ({
            input(&state.gpu_openmp_threads, "OpenMP: "),
            checkbox("Disable multithread", &state.gpu_cpu_nomultithread)
          })
            | with_list_padding | with_separator
            | ftxui::Maybe([&]{ return state.gpu_cpu_scheme_selected == 1; })
        }) | with_title("CPU:", ftxui::Color::GrayDark) | with_separator,
        // 内存
        ftxui::Container::Horizontal
        ({
          ftxui::Menu(&state.gpu_memory_scheme_entries, &state.gpu_memory_scheme_selected),
          input(&state.gpu_memory, "Memory (GB): ")
            | with_list_padding | with_separator
            | ftxui::Maybe([&]{ return state.gpu_memory_scheme_selected == 2; })
        }) | with_title("Memory:", ftxui::Color::GrayDark) | with_separator
      }) | ftxui::Maybe([&]{ return state.program_entries[state.program_selected] == "VASP(GPU)"; }),
    }) | with_title("Resource allocation:") | with_bottom,
    // 第三行：任务名和输出文件
    ftxui::Container::Vertical
    ({
      input(&state.job_name, "Job name: "),
      input(&state.output_file, "Output file: "),
      ftxui::Container::Horizontal
      ({
        checkbox("Generate OPTCELL", &state.optcell_enable),
        ftxui::Menu(&state.optcell_entries, &state.optcell_selected)
          | with_separator
          | ftxui::Maybe([&]{ return state.optcell_enable; })
      })
    }) | with_title("Misc:") | with_bottom_heavy,
    // 操作按钮
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Continue (Enter)",
        [&]{ state.user_command = "continue"; screen.ExitLoopClosure()(); }),
      ftxui::Button("Quit (ESC)",
        [&]{ state.user_command = "quit"; screen.ExitLoopClosure()(); })
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);
  auto confirm_interface = ftxui::Container::Vertical
  ({
    ftxui::Input(&state.submit_command, "", ftxui::InputOption{.multiline = true})
      | with_title("Double check & modify submit command:") | with_bottom_heavy,
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Submit (Enter)",
        [&]{state.user_command = "continue"; screen.ExitLoopClosure()();}),
      ftxui::Button("Back",
        [&]{state.user_command = "back"; screen.ExitLoopClosure()();}),
      ftxui::Button("Quit (ESC)",
        [&]{state.user_command = "quit"; screen.ExitLoopClosure()();})
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);

  // 实际投递任务
  auto submit = [&](std::string submit_command)
  {
    // 保存设置
    try
    {
      std::filesystem::create_directories("{}/.config/sbatch-tui"_f(std::getenv("HOME")));
      std::ofstream("{}/.config/sbatch-tui/config.yaml"_f(std::getenv("HOME"))) << YAML::Node(state);
    }
    catch (...) {}
    // replace \n with space
    boost::replace_all(submit_command, "\n", " ");
    biu::exec<{.DirectStdout = true, .DirectStderr = true, .SearchPath = true}>
      ({"sh", { "-c", submit_command }});
  };

  // 进入事件循环
  while (true)
  {
    screen.Loop(request_interface);
    if (state.user_command == "quit") return 0;
    else if (state.user_command == "continue")
    {
      std::string optcell_string = [&]
      {
        if (state.optcell_enable)
          if (state.optcell_selected == 0) return "echo '000\\n000\\n001' > OPTCELL\n&& "s;
          else if (state.optcell_selected == 1) return "echo '110\\n110\\n000' > OPTCELL\n&& "s;
          else std::unreachable();
        else return ""s;
      }();
      if (state.program_entries[state.program_selected] == "VASP(GPU)")
      {
        auto cpu_string = [&]
        {
          if (state.gpu_cpu_scheme_selected == 0) return "--ntasks=1 --cpus-per-task=1 --hint=nomultithread"s;
          else if (state.gpu_cpu_scheme_selected == 1) return "--ntasks=1 --cpus-per-task={}{}"_f
            (state.gpu_openmp_threads, state.gpu_cpu_nomultithread ? " --hint=nomultithread" : "");
          else std::unreachable();
        }();
        auto gpu_string = [&]
        {
          if (state.gpu_gpu_scheme_selected == 0) return "--gpus=1"s;
          else if (state.gpu_gpu_scheme_selected == 1) return "--gpus={}:1"_f
            (state.gpu_gpu_entries[state.gpu_queue_selected][state.gpu_gpu_selected[state.gpu_queue_selected]]);
          else std::unreachable();
        }();
        auto mem_string = [&]
        {
          if (state.gpu_memory_scheme_selected == 0) return " --mem=24G"s;
          else if (state.gpu_memory_scheme_selected == 1) return ""s;
          else if (state.gpu_memory_scheme_selected == 2) return " --mem={}G"_f(state.gpu_memory);
          else std::unreachable();
        }();
        state.submit_command =
          "{}sbatch --partition={}\n{} {}{}\n--job-name='{}' --output='{}'\n--wrap=\"srun vasp-nvidia vasp-{}\""_f
          (
            optcell_string, state.gpu_queue_entries[state.gpu_queue_selected], gpu_string, cpu_string, mem_string,
            state.job_name, state.output_file, state.vasp_entries[state.vasp_selected]
          );
      }
      else if (state.program_entries[state.program_selected] == "VASP(CPU)")
      {
        auto queue_data = ranges::find_if(device.CpuQueues,
          [&](auto &x){ return x.first == state.cpu_queue_entries[state.cpu_queue_selected]; });
        auto cpu_string = [&]
        {
          if (state.cpu_cpu_scheme_selected == 0)
            if (queue_data->second.AllocateCpus)
              return "--ntasks={} --cpus-per-task=1 --hint=nomultithread"_f(*queue_data->second.AllocateCpus);
            else return "--ntasks={} --cpus-per-task={} --hint=nomultithread"_f
              (queue_data->second.CpuMpiThreads, queue_data->second.CpuOpenmpThreads);
          else if (state.cpu_cpu_scheme_selected == 1) return "--ntasks={} --cpus-per-task={}{}"_f
            (
              state.cpu_mpi_threads, state.cpu_openmp_threads,
              state.cpu_cpu_nomultithread ? " --hint=nomultithread" : ""
            );
          else std::unreachable();
        }();
        auto mem_string = [&]
        {
          if (state.cpu_memory_scheme_selected == 0)
            return queue_data->second.MemoryGB ? " --mem={}G"_f(*queue_data->second.MemoryGB) : "";
          else if (state.cpu_memory_scheme_selected == 1) return ""s;
          else if (state.cpu_memory_scheme_selected == 2) return " --mem={}G"_f(state.cpu_memory);
          else std::unreachable();
        }();
        auto srun_string = [&]
        {
          if (state.cpu_cpu_scheme_selected == 0 && queue_data->second.AllocateCpus)
            return " --ntasks={} --cpus-per-task={}"_f
              (queue_data->second.CpuMpiThreads, queue_data->second.CpuOpenmpThreads);
          else return ""s;
        }();
        state.submit_command =
          "{}sbatch --partition={} --nodes=1-1\n{}{}\n--job-name='{}' --output='{}'\n"
            "--wrap=\"srun{} vasp-intel vasp-{}\""_f
          (
            optcell_string, state.cpu_queue_entries[state.cpu_queue_selected], cpu_string, mem_string,
            state.job_name, state.output_file, srun_string, state.vasp_entries[state.vasp_selected]
          );
      }
      else std::unreachable();
      state.user_command.clear();
    }
    else std::unreachable();
    screen.Loop(confirm_interface);
    if (state.user_command == "quit") return 0;
    else if (state.user_command == "back") { state.user_command.clear(); continue; }
    else if (state.user_command == "continue") { submit(state.submit_command); break; }
    else return EXIT_FAILURE;
  }
}
