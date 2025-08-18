# pragma once
# include <filesystem>
# include <ftxui/component/component.hpp>
# include <ftxui/component/component_options.hpp>
# include <ftxui/component/screen_interactive.hpp>
# include <boost/algorithm/string.hpp>
# include <biu.hpp>

namespace sbatch
{
  using namespace biu::literals;

  class Program
  {
    public: virtual std::string get_name() const = 0;
    public: virtual void load_config(YAML::Node node) = 0;
    public: virtual void try_load_state(YAML::Node node) noexcept = 0;
    public: virtual YAML::Node save_state() const = 0;
    public: virtual ftxui::Component get_interface() = 0;
    public: virtual std::vector<std::string> get_submit_command(std::string extra_sbatch_parameter) const = 0;
    public: virtual ~Program() = default;
    
    // 用于注册程序
    private: static inline std::map<std::string, std::function<std::unique_ptr<Program>()>> Factories_;
    public: static std::unique_ptr<Program> create(std::string name) { return Factories_[name](); }
    protected: template<typename T> [[gnu::constructor]] static inline void register_child_()
      { Factories_[nameof::nameof_short_type<T>().str()] = []{ return std::make_unique<T>(); }; }
  };

  // 为组件增加标题栏
  inline auto with_title(std::string title, ftxui::Color bgcolor = ftxui::Color::Blue)
  {
    return [=](ftxui::Element element)
      { return ftxui::vbox(ftxui::text(title) | ftxui::bgcolor(bgcolor), element); };
  };
  // 为组件增加下边框
  inline auto with_bottom(ftxui::Element element) { return ftxui::vbox(element, ftxui::separatorLight()); };
  // 为组件增加比较粗的下边框
  inline auto with_bottom_heavy(ftxui::Element element)
    { return ftxui::vbox(element, ftxui::separatorHeavy()); };
  // 为组件增加空白以填充界面
  inline auto with_padding(ftxui::Element element)
  {
    auto empty = ftxui::emptyElement() | ftxui::flex_grow;
    return ftxui::vbox(empty, ftxui::hbox(empty, element | ftxui::center, empty), empty);
  };
  // 为纵向列表自动增加空行，有 input 时使用，避免 input 被拉伸成多行
  inline auto with_list_padding(ftxui::Element element)
    { return ftxui::vbox(element, ftxui::emptyElement() | ftxui::flex_grow); };
  // 在组件左边增加分割线
  inline auto with_separator(ftxui::Element element)
    { return ftxui::hbox(ftxui::separatorLight(), element); };
  // 在组件左边增加小标题
  inline auto with_subtitle(std::string title)
    { return [title](ftxui::Element element) { return ftxui::hbox(ftxui::text(title), element); }; };
  // 带标题的文本输入框
  inline auto input(std::string* content, std::string title)
  {
    return ftxui::Input(content) | ftxui::underlined
      | ftxui::size(ftxui::WIDTH, ftxui::GREATER_THAN, 3)
      | ftxui::size(ftxui::HEIGHT, ftxui::EQUAL, 1)
      | with_subtitle(title);
  };
  // 在 putty 上可以正常显示的 checkbox (把勾选框换成 [x])
  inline auto checkbox(std::string title, bool* checked)
  {
    auto checkbox_option = ftxui::CheckboxOption::Simple();
    checkbox_option.transform = [](const ftxui::EntryState& s)
    {
      auto prefix = ftxui::text(s.state ? "[X] " : "[ ] ");
      auto t = ftxui::text(s.label);
      if (s.state) t |= ftxui::bold;
      if (s.focused) t |= ftxui::inverted;
      return ftxui::hbox({prefix, t});
    };
    return ftxui::Checkbox(title, checked, checkbox_option);
  };
  // 转义字符
  inline std::string escape(std::string str)
  {
    return str | ranges::views::transform([](char c)
    {
      // only the following characters need to be escaped: $ ` \ " newline * @ space tab
      if (std::set{'$', '`', '\\', '\"', '\n', '*', '@', ' ', '\t'}.contains(c))
        return '\\' + std::string(1, c);
      else return std::string(1, c);
    }) | ranges::views::join("") | ranges::to<std::string>;
  }
}
