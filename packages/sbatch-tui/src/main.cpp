# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/algorithm/string.hpp>
# include <range/v3/view.hpp>
# include <sbatch-tui/device.hpp>
# include <biu.hpp>

using namespace biu::literals;

int main()
{
  // 需要绑定到界面上的变量
  struct
  {
    int vasp_version_selected = 0;
    std::vector<std::string> vasp_version_entries = { "std", "gam", "ncl" };
    int device_type_selected = 0;
    std::vector<std::string> device_type_entries = { "manually select GPU", "any single GPU", "CPU" };
    std::deque<bool> device_selected = std::deque<bool>(Device.GpuIds.size(), false);
    std::vector<std::string> device_entries = Device.GpuIds;
    std::string job_name = std::filesystem::current_path().filename().string();
    std::string output_file = "output.txt";
    std::string mpi_threads = std::to_string(Device.CpuMpiThreads);
    std::string openmp_threads = std::to_string(Device.CpuOpenmpThreads);

    std::string user_command;
    std::string submit_command;
  } state;

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
    ftxui::Menu(&state.vasp_version_entries, &state.vasp_version_selected)
      | with_title("Select VASP version:"),
    ftxui::Container::Horizontal
    ({
      ftxui::Menu(&state.device_type_entries, &state.device_type_selected),
      ftxui::Container::Vertical([&]
      {
        std::vector<std::shared_ptr<ftxui::ComponentBase>> devices;
        auto checkbox_option = ftxui::CheckboxOption::Simple();
        checkbox_option.transform = [](const ftxui::EntryState& s)
        {
          auto prefix = ftxui::text(s.state ? "[X] " : "[ ] ");
          auto t = ftxui::text(s.label);
          if (s.active) t |= ftxui::bold;
          if (s.focused) t |= ftxui::inverted;
          return ftxui::hbox({prefix, t});
        };
        for (int i = 0; i < state.device_selected.size(); i++)
          devices.push_back(ftxui::Checkbox
            (state.device_entries[i], &state.device_selected[i], checkbox_option));
        return devices;
      }()) | with_separator | ftxui::Maybe([&]{ return state.device_type_selected == 0; }),
      ftxui::Container::Vertical
      ({
        ftxui::Input(&state.mpi_threads) | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
          | with_subtitle("MPI threads: "),
        ftxui::Input(&state.openmp_threads) | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
          | with_subtitle("OpenMP threads: ")
      }) | with_separator | ftxui::Maybe([&]{ return state.device_type_selected == 2; }),
    }) | with_title("Select device:"),
    ftxui::Input(&state.job_name) | with_title("Job name:"),
    ftxui::Input(&state.output_file) | with_title("Output file:"),
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Continue",
        [&]{ state.user_command = "continue"; screen.ExitLoopClosure()(); }),
      ftxui::Button("Quit",
        [&]{ state.user_command = "quit"; screen.ExitLoopClosure()(); })
    })
  }) | ftxui::borderHeavy | with_padding;
  auto confirm_interface = ftxui::Container::Vertical
  ({
    ftxui::Input(&state.submit_command, "", ftxui::InputOption{.multiline = true})
      | with_title("Double check & modify submit command:"),
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Submit",
        [&]{state.user_command = "submit"; screen.ExitLoopClosure()();}),
      ftxui::Button("Quit",
        [&]{state.user_command = "quit"; screen.ExitLoopClosure()();}),
      ftxui::Button("Back",
        [&]{state.user_command = "back"; screen.ExitLoopClosure()();})
    })
  }) | ftxui::borderHeavy | with_padding;

  // 实际投递任务
  auto submit = [](std::string submit_command)
  {
    // replace \n with space
    boost::replace_all(submit_command, "\n", " ");
    biu::exec<{.DirectStdout = true, .DirectStderr = true, .SearchPath = true}>({"sh", { "-c", submit_command }});
  };

  // 进入事件循环
  while (true)
  {
    screen.Loop(request_interface);
    if (state.user_command == "quit") return EXIT_FAILURE;
    else if (state.device_type_selected == 1)
      state.submit_command =
        "sbatch --ntasks=1\n--gpus=1\n--job-name='{}'\n--output='{}'\nvasp-nvidia-{}"_f
        (state.job_name, state.output_file, state.vasp_version_entries[state.vasp_version_selected]);
    else if (state.device_type_selected == 2)
      state.submit_command =
        "sbatch --ntasks={}\n--cpus-per-task={}\n--hint=nomultithread\n--job-name='{}'\n--output='{}'"
        "\nvasp-intel-{}"_f
        (
          state.mpi_threads, state.openmp_threads, state.job_name, state.output_file,
          state.vasp_version_entries[state.vasp_version_selected]
        );
    else
    {
      std::vector<std::string> selected_gpus;
      for (int i = 0; i < state.device_selected.size(); i++)
        if (state.device_selected[i]) selected_gpus.push_back(state.device_entries[i]);
      state.submit_command =
        "sbatch --ntasks={}\n--gres={}\n--job-name='{}'\n--output='{}'\nvasp-nvidia-{}"_f
        (
          selected_gpus.size(),
          selected_gpus
            | ranges::views::transform([](auto& entry) { return "gpu:{}:1"_f(entry); })
            | ranges::views::join(',') | ranges::to<std::string>,
          state.job_name, state.output_file, state.vasp_version_entries[state.vasp_version_selected]
        );
    }
    screen.Loop(confirm_interface);
    if (state.user_command == "quit") return EXIT_FAILURE;
    else if (state.user_command == "back") continue;
    submit(state.submit_command);
    break;
  }
}
