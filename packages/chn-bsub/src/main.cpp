# include <map>
# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/process.hpp>
# include <boost/algorithm/string.hpp>
# include <biu.hpp>

using namespace biu::literals;

int main()
{
	// 需要绑定到界面上的变量
	struct
	{
		std::array<int, 3> vasp_version_selected = {0, 0, 0};
		std::vector<std::string> vasp_version_entries_level1 = {"640", "631"};
		std::map<std::string, std::vector<std::string>> vasp_version_entries_level2 = 
		{
			{"640", {"(default)", "fixc", "optcell_vtst_wannier90", "shmem", "vtst"}},
			{"631", {"shmem"}}
		};
		std::vector<std::string> vasp_version_entries_level3 = {"std", "gam", "ncl"};

		int queue_selected = 0;
		std::vector<std::string> queue_entries =
		{
			"normal_1day", "normal_1week", "normal",
			"normal_1day_new", "ocean_530_1day", "ocean6226R_1day"
		};
		std::map<std::string, std::size_t> max_cores =
		{
			{"normal_1day", 28}, {"normal_1week", 28}, {"normal", 20},
			{"normal_1day_new", 24}, {"ocean_530_1day", 24}, {"ocean6226R_1day", 32}
		};
		std::string ncores = "";
		std::string job_name = []
		{
			// /data/gpfs01/jykang/linwei/chn/lammps-SiC
			std::vector<std::string> paths;
			boost::split(paths, std::filesystem::current_path().string(),
				boost::is_any_of("/"));
			if (paths.size() < 7)
				return "my-great-job"s;
			else
				return paths[5] + "_" + paths.back();
		}();
		std::string bsub = "";
		std::string user_command = "";
	} state;

	// 为组件增加标题栏
	auto component_with_title = [](std::string title, ftxui::Component component)
	{
		return ftxui::Renderer(component, [title, component]
		{
			return ftxui::vbox
			({
				ftxui::text(title) | ftxui::bgcolor(ftxui::Color::Blue),
				component->Render(),
				ftxui::separator()
			});
		});
	};

	// 构建界面, 需要至少 25 行 47 列
	auto screen = ftxui::ScreenInteractive::Fullscreen();
	auto request_interface = [&state, &screen, &component_with_title]
	{
		auto vasp_version_level1 = ftxui::Menu
			(&state.vasp_version_entries_level1, &state.vasp_version_selected[0])
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 8);
		std::vector<ftxui::Component> vasp_version_level2_children;
		for (auto& i : state.vasp_version_entries_level1)
			vasp_version_level2_children.push_back(ftxui::Menu
			(
				&state.vasp_version_entries_level2[i],
				&state.vasp_version_selected[1]
			));
		auto vasp_version_level2 = ftxui::Container::Tab
		(
			vasp_version_level2_children,
			&state.vasp_version_selected[0]
		) | ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 27);
		auto vasp_version_level3 = ftxui::Menu
			(&state.vasp_version_entries_level3, &state.vasp_version_selected[2])
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 8);
		auto vasp_version = component_with_title("Select vasp version:",
			ftxui::Container::Horizontal
				({vasp_version_level1, vasp_version_level2, vasp_version_level3})
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 5));
		auto queue = component_with_title("Select queue:",
			ftxui::Menu(&state.queue_entries, &state.queue_selected)
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 6));
		auto ncores = component_with_title("Input cores you want to use:",
			ftxui::Input(&state.ncores, "(leave blank to use all cores)"))
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 3);
		auto job_name = component_with_title("Job name:",
			ftxui::Input(&state.job_name, ""))
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 3);
		auto continue_button = ftxui::Button("Continue",
			[&]{state.user_command = "continue"; screen.ExitLoopClosure()();});
		auto quit_button = ftxui::Button("Quit",
			[&]{state.user_command = "quit"; screen.ExitLoopClosure()();});
		return ftxui::Container::Vertical
		({
			vasp_version, queue, ncores, job_name,
			ftxui::Container::Horizontal({continue_button, quit_button})
		}) | ftxui::borderHeavy
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 47)
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 24);
	}();
	auto confirm_interface = [&state, &screen, &component_with_title]
	{
		ftxui::InputOption input_option;
		input_option.multiline = true;
		return ftxui::Container::Vertical
		({
			component_with_title
			(
				"Double check & modify submit command:",
				ftxui::Input(&state.bsub, "", input_option)
			)
				| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 7),
			ftxui::Container::Horizontal
			({
				ftxui::Button("Submit",
					[&]{state.user_command = "submit"; screen.ExitLoopClosure()();}),
				ftxui::Button("Quit",
					[&]{state.user_command = "quit"; screen.ExitLoopClosure()();}),
				ftxui::Button("Back",
					[&]{state.user_command = "back"; screen.ExitLoopClosure()();})
			}),
			ftxui::Renderer([]{return ftxui::vbox
			({
				ftxui::separator(),
				ftxui::text("Source code:"),
				ftxui::text("https://github.com/CHN-beta/chn_bsub.git"),
				ftxui::text("Star & PR are welcome!"),
			});})
		}) | ftxui::borderHeavy
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 47)
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 14);
	}();

	// 实际投递任务
	auto submit = [](std::string bsub)
	{
		// replace \n with space
		boost::replace_all(bsub, "\n", " ");
		auto process = boost::process::child
		(
			boost::process::search_path("sh"), "-c", bsub,
			boost::process::std_in.close(),
			boost::process::std_out > stdout,
			boost::process::std_err > stderr
		);
		process.wait();
	};

	// 进入事件循环
	while (true)
	{
		screen.Loop(request_interface);
		if (state.user_command == "quit")
			return EXIT_FAILURE;
		else if (state.user_command != "continue")
			throw std::runtime_error("user_command is not recognized");
		state.bsub = fmt::format
		(
			"bsub -J '{}'\n-q {}\n-n {}\n-R 'span[hosts=1]'\n-o 'output.txt'\nchn_vasp.sh {}",
			state.job_name,
			state.queue_entries[state.queue_selected],
			state.ncores.empty() ? state.max_cores[state.queue_entries[state.queue_selected]] :
				std::stoi(state.ncores),
			[&]
			{
				auto version_level1 = state.vasp_version_entries_level1[state.vasp_version_selected[0]];
				auto version_level2 = state.vasp_version_entries_level2[version_level1]
					[state.vasp_version_selected[1]];
				auto version_level3 = state.vasp_version_entries_level3[state.vasp_version_selected[2]];
				return fmt::format
				(
					"{}{}_{}",
					version_level1,
					version_level2 == "(default)" ? ""s : "_" + version_level2,
					version_level3
				);
			}()
		);
		screen.Loop(confirm_interface);
		if (state.user_command == "quit")
			return EXIT_FAILURE;
		else if (state.user_command == "back")
			continue;
		else if (state.user_command != "submit")
			throw std::runtime_error("user_command is not recognized");
		submit(state.bsub);
		break;
	}
}
