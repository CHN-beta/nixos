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
    // Queue : { CpuMpiThreads, CpuOpenmpThreads, MemoryGB }
    struct CpuQueueType { int CpuMpiThreads, CpuOpenmpThreads, MemoryGB; };
    std::vector<std::pair<std::string, CpuQueueType>> CpuQueues;
    std::optional<std::vector<std::string>> GpuIds;
    std::string GpuPartition;
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
    int queue_selected = 0;
    std::vector<std::string> queue_entries; // 稍后初始化
    std::string mpi_threads;
    std::string openmp_threads;

    // 第二行，如果是GPU，要选择的方案和设备
    int gpu_scheme_selected = 0;
    std::vector<std::string> gpu_scheme_entries = { "manually select a GPU", "any single GPU" };
    int gpu_selected = 0;
    std::vector<std::string> gpu_entries; // 稍后初始化

    // 第三行和第四行，任务名和输出文件
    std::string job_name = std::filesystem::current_path().filename().string();
    std::string output_file = "output.txt";

    // 用户选定的操作
    std::string user_command;

    // 生成的提交命令
    std::string submit_command;
  } state =
  {
    .program_entries = [&]
    {
      std::vector<std::string> entries;
      if (device.GpuIds) entries.push_back("VASP(GPU)");
      entries.push_back("VASP(CPU)");
      return entries;
    }(),
    .queue_entries = device.CpuQueues | ranges::views::keys | ranges::to_vector,
    .gpu_entries = device.GpuIds.value_or(std::vector<std::string>{})
  };

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
    if (saved_state.queue_selected < state.queue_entries.size())
      state.queue_selected = saved_state.queue_selected;
    if (saved_state.gpu_scheme_selected < state.gpu_scheme_entries.size())
      state.gpu_scheme_selected = saved_state.gpu_scheme_selected;
    if (saved_state.gpu_selected < state.gpu_entries.size())
      state.gpu_selected = saved_state.gpu_selected;
    state.mpi_threads = saved_state.mpi_threads;
    state.openmp_threads = saved_state.openmp_threads;
  }
  catch (...) {}

  // 刷新状态
  auto refresh_state = [&]
  {
    // 如果选择了 CPU 程序，那么按照选定的队列刷新 MPI 和 OpenMP 线程数
    if (state.program_entries[state.program_selected] == "VASP(CPU)")
    {
      auto it = ranges::find_if(device.CpuQueues,
        [&](auto &x){ return x.first == state.queue_entries[state.queue_selected]; });
      state.mpi_threads = std::to_string(it->second.CpuMpiThreads);
      state.openmp_threads = std::to_string(it->second.CpuOpenmpThreads);
    }
  };

  // 为组件增加标题栏和分割线
  auto with_title = [](std::string title)
  {
    return [title](ftxui::Element element)
    {
      return ftxui::vbox
        (ftxui::text(title) | ftxui::bgcolor(ftxui::Color::Blue), element, ftxui::separatorLight());
    };
  };
  // 为组件增加空白以填充界面
  auto with_padding = [](ftxui::Element element) -> ftxui::Element
  {
    auto empty = ftxui::emptyElement() | ftxui::flex_grow;
    return ftxui::vbox(empty, ftxui::hbox(empty, element | ftxui::center, empty), empty);
  };
  // 在组件左边增加分割线
  auto with_separator = [](ftxui::Element element)
    { return ftxui::hbox(ftxui::separatorLight(), element); };
  // 在组件左边增加小标题
  auto with_subtitle = [](std::string title)
    { return [title](ftxui::Element element) { return ftxui::hbox(ftxui::text(title), element); }; };

  // 构建界面
  auto screen = ftxui::ScreenInteractive::Fullscreen();
  auto request_interface = ftxui::Container::Vertical
  ({
    // 第一行：选择程序
    ftxui::Container::Horizontal
    ({
      // 左侧：选择程序
      ftxui::Menu(&state.program_entries, &state.program_selected, ftxui::MenuOption{.on_change = refresh_state}),
      // 右侧：选择 VASP 版本
      ftxui::Menu(&state.vasp_entries, &state.vasp_selected) | with_separator
    }) | with_title("Program:"),
    // 第二行
    ftxui::Container::Horizontal
    ({
      // 如果是选择 CPU 程序
      ftxui::Container::Horizontal
      ({
        // 左侧：选择队列
        ftxui::Menu(&state.queue_entries, &state.queue_selected, ftxui::MenuOption{.on_change = refresh_state}),
        // 右侧：输入 MPI 和 OpenMP 线程数，以及内存
        ftxui::Container::Vertical
        ({
          ftxui::Input(&state.mpi_threads) | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
            | with_subtitle("MPI threads: "),
          ftxui::Input(&state.openmp_threads) | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
            | with_subtitle("OpenMP threads: ")
        }) | with_separator
      }) | ftxui::Maybe([&]{ return state.program_entries[state.program_selected] == "VASP(CPU)"; }),
      // 如果是选择 GPU 程序
      ftxui::Container::Horizontal
      ({
        // 左侧：选择方案
        ftxui::Menu(&state.gpu_scheme_entries, &state.gpu_scheme_selected,
          ftxui::MenuOption{.on_change = refresh_state}),
        // 右侧：选择 GPU
        ftxui::Menu(&state.gpu_entries, &state.gpu_selected) | with_separator
          | ftxui::Maybe
            ([&]{ return state.gpu_scheme_entries[state.gpu_scheme_selected] == "manually select a GPU"; })
      }) | ftxui::Maybe([&]{ return state.program_entries[state.program_selected] == "VASP(GPU)"; }),
    }) | with_title("Resource allocation parameters:"),
    // 第三行：任务名
    ftxui::Input(&state.job_name) | with_title("Job name:"),
    // 第四行：输出文件
    ftxui::Input(&state.output_file) | with_title("Output file:"),
    // 操作按钮
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Continue (Enter)",
        [&]{ state.user_command = "continue"; screen.ExitLoopClosure()(); }),
      ftxui::Button("Quit",
        [&]{ state.user_command = "quit"; screen.ExitLoopClosure()(); })
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent([&](ftxui::Event event)
  {
    if (event == ftxui::Event::Return) { state.user_command = "continue"; screen.ExitLoopClosure()(); }
    return event == ftxui::Event::Return;
  });
  auto confirm_interface = ftxui::Container::Vertical
  ({
    ftxui::Input(&state.submit_command, "", ftxui::InputOption{.multiline = true})
      | with_title("Double check & modify submit command:"),
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Submit (Enter)",
        [&]{state.user_command = "submit"; screen.ExitLoopClosure()();}),
      ftxui::Button("Quit",
        [&]{state.user_command = "quit"; screen.ExitLoopClosure()();}),
      ftxui::Button("Back",
        [&]{state.user_command = "back"; screen.ExitLoopClosure()();})
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent([&](ftxui::Event event)
  {
    if (event == ftxui::Event::Return) { state.user_command = "submit"; screen.ExitLoopClosure()(); }
    return event == ftxui::Event::Return;
  });

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
    // 开始之前需要先刷新状态
    refresh_state();
    screen.Loop(request_interface);
    if (state.user_command == "quit") return 0;
    else if (state.user_command == "continue")
    {
      if (state.program_entries[state.program_selected] == "VASP(GPU)")
        if (state.gpu_scheme_entries[state.gpu_scheme_selected] == "any single GPU")
          state.submit_command =
            "sbatch --partition={}\n--ntasks=1 --cpus-per-gpu=1 --gpus=1 --mem=16G\n--job-name='{}' --output='{}'\n"
              "--wrap=\"vasp-nvidia srun vasp-{}\""_f
            (device.GpuPartition, state.job_name, state.output_file, state.vasp_entries[state.vasp_selected]);
        else
          state.submit_command =
            "sbatch --partition={}\n--ntasks=1 --cpus-per-gpu=1 --gpus={}:1 --mem=16G\n--job-name='{}' --output='{}'\n"
              "--wrap=\"vasp-nvidia srun vasp-{}\""_f
            (
              device.GpuPartition, state.gpu_entries[state.gpu_selected],
              state.job_name, state.output_file, state.vasp_entries[state.vasp_selected]
            );
      else state.submit_command =
        "sbatch --partition={} --nodes=1-1\n--ntasks={} --cpus-per-task={} --mem={}G\n--job-name='{}' --output='{}'\n"
          "--wrap=\"vasp-intel srun vasp-{}\""_f
        (
          state.queue_entries[state.queue_selected],
          state.mpi_threads, state.openmp_threads, state.job_name, state.output_file,
          ranges::find_if(device.CpuQueues,
            [&](auto &x){ return x.first == state.queue_entries[state.queue_selected]; })->second.MemoryGB,
          state.vasp_entries[state.vasp_selected]
        );
      state.user_command.clear();
    }
    else return EXIT_FAILURE;
    screen.Loop(confirm_interface);
    if (state.user_command == "quit") return 0;
    else if (state.user_command == "back") { state.user_command.clear(); continue; }
    else if (state.user_command == "submit") { submit(state.submit_command); break; }
    else return EXIT_FAILURE;
  }
}
