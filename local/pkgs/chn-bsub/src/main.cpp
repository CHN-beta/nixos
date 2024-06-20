# include <map>
# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <ftxui/dom/table.hpp>
# include <boost/process.hpp>
# include <boost/algorithm/string.hpp>
# include <range/v3/range.hpp>
# include <range/v3/view.hpp>
# include <nlohmann/json.hpp>
# include <biu.hpp>

using namespace biu::literals;

int main()
{
  // 需要绑定到界面上的变量
  struct
  {
    std::array<int, 3> vasp_version_selected = { 0, 0, 0 };
    std::vector<std::string> vasp_version_entries_level1 = { "640", "631" };
    std::map<std::string, std::vector<std::string>> vasp_version_entries_level2 = 
    {
      { "640", { "(default)", "fixc", "optcell_vtst_wannier90", "shmem", "vtst" }},
      { "631", { "shmem" } }
    };
    std::vector<std::string> vasp_version_entries_level3 = { "std", "gam", "ncl" };

    int queue_selected = 0;
    std::vector<std::string> queue_entries =
    {
      "normal_1day", "normal_1day_new", "ocean_530_1day", "ocean6226R_1day",
      "normal_1week", "normal_2week", "normal"
    };
    std::atomic<bool> queue_detail_show = false;
    std::map<std::string, std::string> queue_hosts =
    {
      { "normal_1day", "normal_1day" },
      { "normal_1day_new", "charge_s_normal" },
      { "ocean_530_1day", "hd_sd530" },
      { "ocean6226R_1day", "hd_sd530_6226R" },
      { "normal_1week", "normal_1week" },
      { "normal_2week", "b_node" },
      { "normal", "cnodes" }
    };
    std::map<std::string, std::string> queue_timelimit =
    {
      { "normal_1day", "1 day" },
      { "normal_1day_new", "1 day" },
      { "ocean_530_1day", "1 day" },
      { "ocean6226R_1day", "1 day" },
      { "normal_1week", "7 day" },
      { "normal_2week", "14 day" },
      { "normal", "14 day" }
    };
    std::optional<std::vector<std::vector<std::string>>> queue_detail = [this]
      -> std::optional<std::vector<std::vector<std::string>>>
    {
      std::vector<std::vector<std::string>> result;
      result.push_back({ "number of nodes (total/busy/free)" });
      for (auto& queue : queue_entries)
      {
        if
        (
          auto result = biu::exec<{.SearchPath=true}>
            ("bhosts", { "-o", "hname max run", "-json", queue_hosts[queue] });
          !result
        )
          return std::nullopt;
        else
        {
          auto json = nlohmann::json::parse(result.Stdout);
          auto total = json["HOSTS"].get<std::size_t>();
          auto records = json["RECORDS"].get<std::vector<nlohmann::json>>();
          auto busy = (records
            | ranges::views::filter
              ([](auto& record){ return record["RUN"].template get<std::size_t>() > 0; })).size();
          auto free = total - busy;
        }
      }
      return result;
    }();
    std::string ncores = "";
    std::string job_name = []
    {
      // /data/gpfs01/jykang/linwei/chn/lammps-SiC
      std::vector<std::string> paths;
      boost::split(paths, std::filesystem::current_path().string(), boost::is_any_of("/"));
      if (paths.size() < 7) return "my-great-job"s;
      else return paths[5] + "_" + paths.back();
    }();
    std::string bsub = "";
    std::string user_command = "";
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
    ftxui::Container::Horizontal
    ({
      ftxui::Menu(&state.vasp_version_entries_level1, &state.vasp_version_selected[0]),
      ftxui::Container::Tab
      (
        {
          ftxui::Menu(&state.vasp_version_entries_level2[0], &state.vasp_version_selected[1]),
          ftxui::Menu(&state.vasp_version_entries_level2[1], &state.vasp_version_selected[1])
        },
        &state.vasp_version_selected[0]
      ) | with_separator,
      ftxui::Menu(&state.vasp_version_entries_level3, &state.vasp_version_selected[2]) | with_separator
    }) | with_title("VASP version"),
    ftxui::Container::Horizontal
    ({
      ftxui::Menu(&state.queue_entries, &state.queue_selected) | with_title("Queue\n"),
      ftxui::Table
      (
        state.queue_detail
          | ranges::views::transform([](auto& line){ line | ranges::views::transform([](auto& text){ return ftxui::text() }) })
    })




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
    })



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
      }()) | with_separator | ftxui::Maybe([&]{ return state.device_type_selected == 1; }),
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
  
  [&state, &screen]
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
