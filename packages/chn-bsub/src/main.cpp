# include <biu.hpp>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/process.hpp>
# include <boost/algorithm/string.hpp>

# ifndef BSUB_CONFIG
#   define BSUB_CONFIG "./bsub.yaml"
# endif

using namespace biu::literals;

int main()
{
	biu::Logger::Guard log;
	enum class UserCommandType { Continue, Back, Quit };
  enum class InterfaceType { Request, Confirm };
  struct
  {
    std::optional<UserCommandType> UserCommand;
    std::string SubmitCommand;
    InterfaceType CurrentInterface = InterfaceType::Request;
		int VaspSelected = 0;
		std::vector<std::string> VaspEntries = { "std", "gam", "ncl" };
		int QueueSelected = 0;
		std::vector<std::string> QueueEntries;
    std::string JobName = []
		{
			// /data/gpfs01/wlin/chn/lammps-SiC
			std::vector<std::string> paths;
			boost::split(paths, std::filesystem::current_path().string(), boost::is_any_of("/"));
			if (paths.size() < 6) return "my-great-job"s;
			else return paths[4] + "_" + paths.back();
		}();
    std::string OutputFile = "output.txt";
  } State;
	struct { std::map<std::string, std::array<int, 3>> Queues; } QueueConfig =
		YAML::LoadFile(BSUB_CONFIG).as<decltype(QueueConfig)>();
	State.QueueEntries = QueueConfig.Queues
		| ranges::views::transform([](auto const& item) { return item.first; })
		| ranges::to_vector;

  // 为组件增加标题栏
  auto with_title = [](std::string title, ftxui::Color bgcolor = ftxui::Color::Blue)
  {
    return [=](ftxui::Element element)
      { return ftxui::vbox(ftxui::text(title) | ftxui::bgcolor(bgcolor), element); };
  };
  // 为组件增加下边框
  auto with_bottom = [](ftxui::Element element)
		{ return ftxui::vbox(element, ftxui::separatorLight()); };
  // 为组件增加比较粗的下边框
  auto with_bottom_heavy = [](ftxui::Element element)
    { return ftxui::vbox(element, ftxui::separatorHeavy()); };
  // 在组件左边增加小标题
  auto with_subtitle = [](std::string title)
    { return [title](ftxui::Element element) { return ftxui::hbox(ftxui::text(title), element); }; };
  // 带标题的文本输入框
  auto input = [with_subtitle](std::string* content, std::string title)
  {
    return ftxui::Input(content) | ftxui::underlined
      | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
      | ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 1)
      | with_subtitle(title);
  };
  // 在组件左边增加分割线
  auto with_separator = [](ftxui::Element element)
		{ return ftxui::hbox(ftxui::separatorLight(), element); };
  // 为组件增加空白以填充界面
  auto with_padding = [](ftxui::Element element)
  {
    auto empty = ftxui::emptyElement() | ftxui::flex_grow;
    return ftxui::vbox(empty, ftxui::hbox(empty, element | ftxui::center, empty), empty);
  };
  // 转义字符
  auto escape = [](std::string str)
  {
    return str | ranges::views::transform([](char c)
    {
      // only the following characters need to be escaped: $ ` \ " newline * @ space tab
      if (std::set{'$', '`', '\\', '\"', '\n', '*', '@', ' ', '\t'}.contains(c))
        return '\\' + std::string(1, c);
      else return std::string(1, c);
    }) | ranges::views::join("") | ranges::to<std::string>;
  };

	// 构建界面
  auto Screen = ftxui::ScreenInteractive::Fullscreen();
  auto key_event_handler = [&](ftxui::Event event)
  {
    if (event == ftxui::Event::Return)
      { State.UserCommand = UserCommandType::Continue; Screen.ExitLoopClosure()(); return true; }
    else return false;
  };
  auto InterfaceRequest = ftxui::Container::Vertical
	({
		ftxui::Container::Horizontal
		({
			ftxui::Menu(&State.VaspEntries, &State.VaspSelected) | with_title("VASP variant:"),
			ftxui::Menu(&State.QueueEntries, &State.QueueSelected)
				| with_title("Queue:") | with_separator
		}) | with_bottom_heavy,
		input(&State.JobName, "Job name: "),
		input(&State.OutputFile, "Output file: "),
		// 操作按钮
		ftxui::Container::Horizontal
		({
			ftxui::Button("Continue (Enter)",
				[&]{ State.UserCommand = UserCommandType::Continue; Screen.ExitLoopClosure()(); }),
			ftxui::Button("Quit",
				[&]{ State.UserCommand = UserCommandType::Quit; Screen.ExitLoopClosure()(); })
		}),
	}) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);
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
      ftxui::Button("Quit",
        [&]{State.UserCommand = UserCommandType::Quit; Screen.ExitLoopClosure()();})
    })
  }) | ftxui::borderHeavy | with_padding | ftxui::CatchEvent(key_event_handler);

  // 进入事件循环
  while (true)
  {
    if (State.CurrentInterface == InterfaceType::Request)
    {
      State.UserCommand.reset();
      Screen.Loop(InterfaceRequest);
      if (State.UserCommand == UserCommandType::Quit) return 0;
      else if (State.UserCommand == UserCommandType::Continue)
      {
        State.CurrentInterface = InterfaceType::Confirm;
        State.SubmitCommand = [&]
				{
					auto [nproc, nthr, ncpu] = QueueConfig.Queues.at(State.QueueEntries[State.QueueSelected]);
					auto args = std::vector<std::string>
					{
						"bsub",
						"-J {} -o {}"_f(escape(State.JobName), escape(State.OutputFile)),
						"-q {} -n {} -R 'span[hosts=1]'"_f(escape(State.QueueEntries[State.QueueSelected]), ncpu),
						"vasp-intel mpirun -n {} -x OMP_NUM_THREADS={} vasp-{}"_f
							(nproc, nthr, State.VaspEntries[State.VaspSelected])
					};
					return args | ranges::views::join(" \\\n ") | ranges::to<std::string>;
				}();
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
      else if (State.UserCommand == UserCommandType::Continue)
      {
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
