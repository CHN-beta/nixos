# include <biu.hpp>

int main()
{
  using namespace biu::literals;
  std::string s1 = "Job <462270> is submitted to queue <normal_1day>.";
  std::string s2 = "Job <462270> is submitted to default queue <normal>.";
  std::regex re(R"r(Job <(\d+)> is submitted to(?: default)? queue <(\w+)>.)r");
  std::smatch match;
  assert(std::regex_match(s1, match, re) && ("{}_{}"_f(match[1], match[2]) == "462270_normal_1day"));
  assert(std::regex_match(s2, match, re) && ("{}_{}"_f(match[1], match[2]) == "462270_normal"));
}
