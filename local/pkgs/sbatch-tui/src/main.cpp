# include <map>
# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/process.hpp>
# include <boost/algorithm/string.hpp>
# include <fmt/format.h>
# include <range/v3/view.hpp>
# include <sbatch-tui/device.hpp>

using namespace fmt::literals;
using namespace std::literals;

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
		auto vasp_version = component_with_title
		(
			"Select VASP version:",
			ftxui::Menu(&state.vasp_version_entries, &state.vasp_version_selected)
		)
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 30);
		auto device = component_with_title
		(
			"Select device:",
			ftxui::Menu(&state.device_entries, &state.device_selected)
		)
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 30);
		auto continue_button = ftxui::Button("Continue",
			[&]{ state.user_command = "continue"; screen.ExitLoopClosure()(); });
		auto quit_button = ftxui::Button("Quit",
			[&]{ state.user_command = "quit"; screen.ExitLoopClosure()(); });
		return ftxui::Container::Vertical
		({
			vasp_version, device,
			ftxui::Container::Horizontal({continue_button, quit_button})
		}) | ftxui::borderHeavy
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 30)
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 18);
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
				ftxui::Input(&state.submit_command, "", input_option)
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
			})
		}) | ftxui::borderHeavy
			| ftxui::size(ftxui::WIDTH, ftxui::EQUAL, 30)
			| ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 18);
	}();

	// 实际投递任务
	auto submit = [](std::string submit_command)
	{
		// replace \n with space
		boost::replace_all(submit_command, "\n", " ");
		auto process = boost::process::child
		(
			boost::process::search_path("sh"), "-c", submit_command,
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
			Device.CpuMpiThreads, Device.CpuOpenMPThreads, std::filesystem::current_path().filename().string(),
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
