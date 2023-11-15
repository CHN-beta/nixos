# include <iostream>
# include <set>
# include <sstream>
# include <filesystem>
# include <cereal/types/set.hpp>
# include <cereal/archives/json.hpp>
# include <fmt/format.h>
# include <fmt/ranges.h>
# include <httplib.h>
# include <json/json.h>

std::string urlencode(std::string s)
{
  auto hexchar = [](unsigned char c, unsigned char &hex1, unsigned char &hex2)
  {
    hex1 = c / 16;
    hex2 = c % 16;
    hex1 += hex1 <= 9 ? '0' : 'a' - 10;
    hex2 += hex2 <= 9 ? '0' : 'a' - 10;
  };
  const char *str = s.c_str();
  std::vector<char> v(s.size());
  v.clear();
  for (std::size_t i = 0, l = s.size(); i < l; i++)
  {
    char c = str[i];
    if
    (
      (c >= '0' && c <= '9')
        || (c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z')
        || c == '-' || c == '_' || c == '.' || c == '!' || c == '~'
        || c == '*' || c == '\'' || c == '(' || c == ')'
    )
      v.push_back(c);
    else
    {
      v.push_back('%');
      unsigned char d1, d2;
      hexchar(c, d1, d2);
      v.push_back(d1);
      v.push_back(d2);
    }
  }
  return std::string(v.cbegin(), v.cend());
}

void oneshot
(
  const std::string& username, const std::string& password, const std::string& comment,
  const std::set<std::string>& wxuser, const std::set<std::string>& manager, const std::string& token
)
{
  httplib::Client fzclient("http://scmv9.fengzhansy.com:8882");
  httplib::Client wxclient("http://wxpusher.zjiecode.com");
  auto& log = std::clog;

  try
  {
    // get JSESSIONID
    auto cookie_jsessionid = [&]() -> std::string
    {
      log << "get /scmv9/login.jsp\n";
      auto result = fzclient.Get("/scmv9/login.jsp");
      if (result.error() != httplib::Error::Success)
        throw std::runtime_error("request failed");
      auto it = result.value().headers.find("Set-Cookie");
      if (it == result.value().headers.end() || it->first != "Set-Cookie")
        throw std::runtime_error("find cookie failed");
      log << fmt::format("set_cookie JSESSIONID {}\n", it->second.substr(0, it->second.find(';')));
      return it->second.substr(0, it->second.find(';'));
    }();

    // login
    auto cookie_pppp = [&]() -> std::string
    {
      auto body = fmt::format("method=dologinajax&rand=1234&userc={}&mdid=P&passw={}", username, password);
      httplib::Headers headers =
      {
        { "X-Requested-With", "XMLHttpRequest" },
        {
          "User-Agent",
          "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36"
        },
        { "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8" },
        { "Origin", "http://scmv9.fengzhansy.com:8882" },
        { "Referer", "http://scmv9.fengzhansy.com:8882/scmv9/login.jsp" },
        { "Cookie", cookie_jsessionid }
      };
      log << "post /scmv9/data.jsp\n";
      auto result = fzclient.Post("/scmv9/data.jsp", headers, body, "application/x-www-form-urlencoded; charset=UTF-8");
      if (result.error() != httplib::Error::Success)
        throw std::runtime_error("request failed");
      log << fmt::format("set_cookie pppp {}\n", fmt::format("pppp={}%40{}", username, password));
      return fmt::format("pppp={}%40{}", username, password);
    }();

    // get order list
    auto order_list = [&]() -> std::map<std::string, std::pair<std::string, std::string>>
    {
      auto body = fmt::format("method=dgate&rand=1234&op=scmmgr_pcggl&nv%5B%5D=opmode&nv%5B%5D=dd_qry&nv%5B%5D=bill&nv%5B%5D=&nv%5B%5D=storeid&nv%5B%5D=&nv%5B%5D=vendorid&nv%5B%5D={}&nv%5B%5D=qr_status&nv%5B%5D=&nv%5B%5D=ddprt&nv%5B%5D=%25&nv%5B%5D=fdate&nv%5B%5D=&nv%5B%5D=tdate&nv%5B%5D=&nv%5B%5D=shfdate&nv%5B%5D=&nv%5B%5D=shtdate&nv%5B%5D=&nv%5B%5D=fy_pno&nv%5B%5D=1&nv%5B%5D=fy_psize&nv%5B%5D=10", username);
      httplib::Headers headers =
      {
        { "X-Requested-With", "XMLHttpRequest" },
        {
          "User-Agent",
          "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36"
        },
        { "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8" },
        { "Origin", "http://scmv9.fengzhansy.com:8882"
        },
        { "Referer", "http://scmv9.fengzhansy.com:8882/scmv9/SCM/cggl_po_qry.jsp" },
        { "Cookie", fmt::format("{}; {}", cookie_jsessionid, cookie_pppp) }
      };
      log << "post /scmv9/data.jsp\n";
      auto result = fzclient.Post("/scmv9/data.jsp", headers, body, "application/x-www-form-urlencoded; charset=UTF-8");
      if (result.error() != httplib::Error::Success)
        throw std::runtime_error("request failed");
      log << fmt::format("get result {}\n", result.value().body);
      std::stringstream result_body(result.value().body);
      Json::Value root;
      result_body >> root;
      std::map<std::string, std::pair<std::string, std::string>> orders;
      for (unsigned i = 0; i < root["dt"][1].size(); i++)
      {
        log << fmt::format
        (
          "insert order {} {} {}\n", root["dt"][1][i].asString(), root["dt"][2][i].asString(),
          root["dt"][4][i].asString()
        );
        orders.insert({root["dt"][1][i].asString(), {root["dt"][2][i].asString(), root["dt"][4][i].asString()}});
      }
      return orders;
    }();

    // read order old
    auto order_old = [&]() -> std::set<std::string>
    {
      if (!std::filesystem::exists("orders.json"))
        return {};
      else
      {
        std::ifstream ins("orders.json");
        cereal::JSONInputArchive ina(ins);
        std::set<std::string> data;
        cereal::load(ina, data);
        return data;
      }
    }();

    // push new order info
    for (const auto& order : order_list)
      if (!order_old.contains(order.first))
      {
        for (const auto& user : manager)
        {
          auto path = fmt::format
          (
            "/api/send/message/?appToken={}&content={}&uid={}",
            token, urlencode(fmt::format("push {}", order.first)), user
          );
          auto wxresult = wxclient.Get(path.c_str());
        }

        auto body = fmt::format
        (
          "method=dgate&rand=1234&op=scmmgr_pcggl&nv%5B%5D=opmode&nv%5B%5D=ddsp_qry&nv%5B%5D=bill&nv%5B%5D={}",
          order.first
        );
        httplib::Headers headers =
        {
          { "X-Requested-With", "XMLHttpRequest" },
          {
            "User-Agent",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36"
          },
          { "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8" },
          { "Origin", "http://scmv9.fengzhansy.com:8882" },
          { "Referer", "http://scmv9.fengzhansy.com:8882/scmv9/SCM/cggl_po_qry.jsp" },
          { "Cookie", fmt::format("{}; {}", cookie_jsessionid, cookie_pppp) }
        };
        log << "post /scmv9/data.jsp\n";
        auto result = fzclient.Post
          ("/scmv9/data.jsp", headers, body, "application/x-www-form-urlencoded; charset=UTF-8");
        if (result.error() != httplib::Error::Success)
          throw std::runtime_error("request failed");
        log << fmt::format("get result {}\n", result.value().body);
        std::stringstream result_body(result.value().body);
        Json::Value root;
        result_body >> root;

        std::stringstream push_body;
        double all_cost = 0;
        push_body << fmt::format
        (
          "{} {} {}店\n", comment, order.second.second.substr(order.second.second.find('-') + 1),
          order.second.first.substr(1, 2)
        );
        for (unsigned i = 0; i < root["dt"][6].size(); i++)
        {
          push_body << fmt::format
          (
            "{} {}{}\n", root["dt"][6][i].asString().substr(root["dt"][6][i].asString().length() - 4),
            root["dt"][7][i].asString(), root["dt"][5][i].asString()
          );
          // 订货金额 maybe empty ???
          if (root["dt"][10][i].asString() != "")
            all_cost += std::stod(root["dt"][10][i].asString());
        }
        push_body << fmt::format("共{:.2f}元\n", all_cost);
        log << fmt::format("push to wx {}\n", push_body.str());
        auto encoded = urlencode(push_body.str());
            
        for (const auto& wxu : wxuser)
        {
          auto path = fmt::format
            ("/api/send/message/?appToken={}&content={}&uid={}", token, encoded, wxu);
          auto wxresult = wxclient.Get(path.c_str());
        }
      }

    // save data
    {
      for (const auto& order : order_list)
        if (!order_old.contains(order.first))
          order_old.insert(order.first);
      std::ofstream os("orders.json");
      cereal::JSONOutputArchive oa(os);
      cereal::save(oa, order_old);
    }
  }
  catch (const std::exception& ex)
  {
    log << ex.what() << "\n" << std::flush;
    std::terminate();
  }
}

int main(int argc, char** argv)
{
  Json::Value configs;
  std::ifstream("@config_file@") >> configs;
  auto config_uids = configs["uids"];
  std::set<std::string> uids;
  for (auto& uid : config_uids)
    uids.insert(uid.asString());
  for (auto& config : configs["config"])
    oneshot
    (
      config["username"].asString(), config["password"].asString(), config["comment"].asString(),
      uids, { configs["manager"].asString() }, configs["token"].asString()
    );
}

