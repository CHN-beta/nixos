# include <sbatch-tui.hpp>

# ifndef SBATCH_CONFIG
#   define SBATCH_CONFIG "./sbatch-tui.yaml"
# endif

int main()
{
  using namespace biu::literals;
  using namespace sbatch;

  // 初始化
  struct
  {
    int ProgramSelected = 0;
    std::vector<std::string> ProgramEntries;
    std::string UserCommand;
    std::string SubmitCommand;
    std::string CurrentInterface = "Program";
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
    if (event == ftxui::Event::Return) { State.UserCommand = "Continue"; Screen.ExitLoopClosure()(); return true; }
    else return false;
  };
  auto InterfaceProgram = ftxui::Container::Vertical
  ({
    ftxui::Menu(&State.ProgramEntries, &State.ProgramSelected)
      | sbatch::with_title("Program:") | with_bottom_heavy,
    ftxui::Container::Horizontal
    ({
      ftxui::Button("Continue (Enter)",
        [&]{ State.UserCommand = "Continue"; Screen.ExitLoopClosure()(); }),
      ftxui::Button("Quit",
        [&]{ State.UserCommand = "Quit"; Screen.ExitLoopClosure()(); })
    }),
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);
  auto get_interface_request = [&](ftxui::Component program_interface)
  {
    return ftxui::Container::Vertical
    ({
      Programs[State.ProgramSelected]->get_interface() | with_bottom_heavy,
      // 操作按钮
      ftxui::Container::Horizontal
      ({
        ftxui::Button("Continue (Enter)",
          [&]{ State.UserCommand = "Continue"; Screen.ExitLoopClosure()(); }),
        ftxui::Button("Back",
          [&]{State.UserCommand = "Back"; Screen.ExitLoopClosure()();}),
        ftxui::Button("Quit",
          [&]{ State.UserCommand = "Quit"; Screen.ExitLoopClosure()(); })
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
        [&]{State.UserCommand = "Continue"; Screen.ExitLoopClosure()();}),
      ftxui::Button("Back",
        [&]{State.UserCommand = "Back"; Screen.ExitLoopClosure()();}),
      ftxui::Button("Quit",
        [&]{State.UserCommand = "Quit"; Screen.ExitLoopClosure()();})
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);

  // 进入事件循环
  while (true)
  {
    if (State.CurrentInterface == "Program")
    {
      State.UserCommand = "Quit";
      Screen.Loop(InterfaceProgram);
      if (State.UserCommand == "Quit") return 0;
      else if (State.UserCommand == "Continue") State.CurrentInterface = "Request";
      else std::unreachable();
    }
    else if (State.CurrentInterface == "Request")
    {
      State.UserCommand = "Quit";
      Screen.Loop(get_interface_request(Programs[State.ProgramSelected]->get_interface()));
      if (State.UserCommand == "Quit") return 0;
      else if (State.UserCommand == "Back") { State.CurrentInterface = "Program"; }
      else if (State.UserCommand == "Continue")
      {
        State.CurrentInterface = "Confirm";
        State.SubmitCommand = Programs[State.ProgramSelected]->get_submit_command();
      }
      else std::unreachable();
    }
    else if (State.CurrentInterface == "Confirm")
    {
      State.UserCommand = "Quit";
      Screen.Loop(InterfaceConfirm);
      if (State.UserCommand == "Quit") return 0;
      else if (State.UserCommand == "Back") { State.CurrentInterface = "Request"; }
      else if (State.UserCommand == "Continue")
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
        boost::replace_all(State.SubmitCommand, "\n", " ");
        biu::exec<{.DirectStdout = true, .DirectStderr = true, .SearchPath = true}>
          ({"sh", { "-c", State.SubmitCommand }});
        break;
      }
      else std::unreachable();
    }
  }
}
