# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/algorithm/string.hpp>
# include <fmt/format.h>
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
    int device_selected = 0;
    std::vector<std::string> device_entries = []
    {
      std::vector<std::string> devices(Device.GpuIds.size() + 2);
      for (std::size_t i = 0; i < Device.GpuIds.size(); ++i)
        devices[i + 1] = Device.GpuIds[i];
      devices[0] = "any single GPU";
      devices.back() = "CPU";
      return devices;
    }();
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

  // 构建界面
  auto screen = ftxui::ScreenInteractive::Fullscreen();
  auto request_interface = ftxui::Container::Vertical
  ({
    ftxui::Menu(&state.vasp_version_entries, &state.vasp_version_selected)
      | with_title("Select VASP version:"),
    ftxui::Menu(&state.device_entries, &state.device_selected)
      | with_title("Select device:"),
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
    biu::common::exec<false, true, true, true>("sh", { "-c", submit_command });
  };

  // 进入事件循环
  while (true)
  {
    screen.Loop(request_interface);
    if (state.user_command == "quit")
      return EXIT_FAILURE;
    else if (state.user_command != "continue")
      throw std::runtime_error("user_command is not recognized");
    else if (state.device_selected < 0 || state.device_selected >= state.device_entries.size())
      throw std::runtime_error("device_selected is out of range");
    else if (state.device_selected == 0) state.submit_command = fmt::format
    (
      "sbatch --ntasks=1\n--gpus=1\n--job-name='{}'\n--output=output.txt\nvasp-nvidia-{}",
      std::filesystem::current_path().filename().string(), state.vasp_version_entries[state.vasp_version_selected]
    );
    else if (state.device_selected == state.device_entries.size() - 1) state.submit_command = fmt::format
    (
      "sbatch --ntasks={}\n--cpus-per-task={}\n--hint=nomultithread\n--job-name='{}'\n--output=output.txt"
        "\nvasp-intel-{}",
      Device.CpuMpiThreads, Device.CpuOpenmpThreads, std::filesystem::current_path().filename().string(),
      state.vasp_version_entries[state.vasp_version_selected]
    );
    else state.submit_command = fmt::format
    (
      "sbatch --ntasks=1\n--gpus={}:1\n--job-name='{}'\n--output=output.txt\nvasp-nvidia-{}",
      state.device_entries[state.device_selected], std::filesystem::current_path().filename().string(),
      state.vasp_version_entries[state.vasp_version_selected]
    );
    screen.Loop(confirm_interface);
    if (state.user_command == "quit")
      return EXIT_FAILURE;
    else if (state.user_command == "back")
      continue;
    else if (state.user_command != "submit")
      throw std::runtime_error("user_command is not recognized");
    submit(state.submit_command);
    break;
  }
}
