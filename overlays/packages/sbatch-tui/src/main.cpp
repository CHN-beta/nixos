# include <sbatch-tui.hpp>

# ifndef SBATCH_CONFIG
#   define SBATCH_CONFIG "./sbatch-tui.yaml"
# endif

int main()
{
  using namespace biu::literals;
  using namespace sbatch;
  biu::Logger::Guard log;

  // 初始化
  enum class UserCommandType { Continue, Back, Quit, Print };
  enum class InterfaceType { Program, Request, Confirm };
  struct
  {
    int ProgramSelected = 0;
    std::vector<std::string> ProgramEntries;
    std::optional<UserCommandType> UserCommand;
    std::string SubmitCommand;
    std::vector<std::string> SubmitCommandLines;
    InterfaceType CurrentInterface = InterfaceType::Program;
    std::string JobName = std::filesystem::current_path().filename().string();
    std::string OutputFile = "output.txt";
    bool LowPriority = false;
  } State;
  std::vector<std::unique_ptr<Program>> Programs;
  auto ConfigFile = YAML::LoadFile(SBATCH_CONFIG);
  for (auto &[name, node]
    : ConfigFile["Program"].as<std::map<std::string, YAML::Node>>())
  {
    auto p = Program::create(name);
    p->load_config(node);
    State.ProgramEntries.push_back(p->get_name());
    Programs.push_back(std::move(p));
  }

  // 读取状态
  try
  {
    auto StateFile = YAML::LoadFile("{}/.config/sbatch-tui/state.yaml"_f(getenv("HOME")));
    if (StateFile["ProgramSelected"].as<int>() < Programs.size())
      State.ProgramSelected = StateFile["ProgramSelected"].as<int>();
    for (auto &program : Programs)
      program->try_load_state(StateFile["Program"][NAMEOF_SHORT_TYPE_RTTI(*program)]);
  }
  catch (...) {}

  // 构建界面
  auto Screen = ftxui::ScreenInteractive::Fullscreen();
  auto key_event_handler = [&](ftxui::Event event)
  {
    if (event == ftxui::Event::Return)
      { State.UserCommand = UserCommandType::Continue; Screen.ExitLoopClosure()(); return true; }
    else return false;
  };
  auto InterfaceProgram = ftxui::Container::Vertical
  ({
    ftxui::Menu(&State.ProgramEntries, &State.ProgramSelected)
      | sbatch::with_title("Program:") | with_bottom_heavy,
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Continue (Enter)",
        [&]{ State.UserCommand = UserCommandType::Continue; Screen.ExitLoopClosure()(); }),
      ftxui::Button("Quit",
        [&]{ State.UserCommand = UserCommandType::Quit; Screen.ExitLoopClosure()(); })
    }),
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);
  auto get_interface_request = [&](ftxui::Component program_interface)
  {
    return ftxui::Container::Vertical
    ({
      Programs[State.ProgramSelected]->get_interface() | with_bottom_heavy,
      input(&State.JobName, "Job name: "),
      input(&State.OutputFile, "Output file: "),
      checkbox("Low priority", &State.LowPriority),
      // 操作按钮
      ftxui::Container::Horizontal
      ({
        ftxui::Button("Continue (Enter)",
          [&]{ State.UserCommand = UserCommandType::Continue; Screen.ExitLoopClosure()(); }),
        ftxui::Button("Back",
          [&]{State.UserCommand = UserCommandType::Back; Screen.ExitLoopClosure()();}),
        ftxui::Button("Quit",
          [&]{ State.UserCommand = UserCommandType::Quit; Screen.ExitLoopClosure()(); })
      }),
    }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);
  };
  auto InterfaceConfirm = ftxui::Container::Vertical
  ({
    ftxui::Input(&State.SubmitCommand, "", ftxui::InputOption{.multiline = true})
      | with_title("Double check & modify submit command:") | with_bottom_heavy,
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Submit (Enter)",
        [&]{State.UserCommand = UserCommandType::Continue; Screen.ExitLoopClosure()();}),
      ftxui::Button("Back",
        [&]{State.UserCommand = UserCommandType::Back; Screen.ExitLoopClosure()();}),
      ftxui::Button("Print Command and Quit",
        [&]{State.UserCommand = UserCommandType::Print; Screen.ExitLoopClosure()();}),
      ftxui::Button("Quit",
        [&]{State.UserCommand = UserCommandType::Quit; Screen.ExitLoopClosure()();})
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);

  // 进入事件循环
  while (true)
  {
    if (State.CurrentInterface == InterfaceType::Program)
    {
      State.UserCommand.reset();
      Screen.Loop(InterfaceProgram);
      if (State.UserCommand == UserCommandType::Quit) return 0;
      else if (State.UserCommand == UserCommandType::Continue) State.CurrentInterface = InterfaceType::Request;
      else if (!State.UserCommand) return EXIT_FAILURE;
      else std::unreachable();
    }
    else if (State.CurrentInterface == InterfaceType::Request)
    {
      State.UserCommand.reset();
      Screen.Loop(get_interface_request(Programs[State.ProgramSelected]->get_interface()));
      if (State.UserCommand == UserCommandType::Quit) return 0;
      else if (State.UserCommand == UserCommandType::Back) { State.CurrentInterface = InterfaceType::Program; }
      else if (State.UserCommand == UserCommandType::Continue)
      {
        State.CurrentInterface = InterfaceType::Confirm;
        State.SubmitCommandLines =
          Programs[State.ProgramSelected]->get_submit_command(
            "--job-name={} --output={}{}"_f
              (escape(State.JobName), escape(State.OutputFile), State.LowPriority ? " --nice=10000" : ""));
        State.SubmitCommand = State.SubmitCommandLines | ranges::views::join(" \\\n ") | ranges::to<std::string>;
      }
      else if (!State.UserCommand) return EXIT_FAILURE;
      else std::unreachable();
    }
    else if (State.CurrentInterface == InterfaceType::Confirm)
    {
      State.UserCommand.reset();
      Screen.Loop(InterfaceConfirm);
      if (State.UserCommand == UserCommandType::Quit) return 0;
      else if (State.UserCommand == UserCommandType::Back) { State.CurrentInterface = InterfaceType::Request; }
      else if (State.UserCommand == UserCommandType::Print)
      {
        std::cout << (State.SubmitCommandLines | ranges::views::join(" ") | ranges::to<std::string>) << std::endl;
        return 0;
      }
      else if (State.UserCommand == UserCommandType::Continue)
      {
        // 尝试保存状态
        try
        {
          std::filesystem::create_directories("{}/.config/sbatch-tui"_f(std::getenv("HOME")));
          YAML::Node state;
          state["ProgramSelected"] = State.ProgramSelected;
          for (auto &program : Programs)
            state["Program"][NAMEOF_SHORT_TYPE_RTTI(*program)] = program->save_state();
          std::ofstream("{}/.config/sbatch-tui/state.yaml"_f(std::getenv("HOME"))) << YAML::Node(state);
        }
        catch (...) {}
        // 提交任务
        log.debug("submit command: {}"_f(State.SubmitCommand));
        // -c 对 \\n 的处理与通常情况下不同，我们需要用 -s 然后将命令通过标准输入传入
        biu::exec<{.SearchPath = true, .Stdin = biu::IoType::String}>
          ({.Program = "sh", .Args = { "-s"}, .Stdin = State.SubmitCommand});
        break;
      }
      else if (!State.UserCommand) return EXIT_FAILURE;
      else std::unreachable();
    }
  }
}
