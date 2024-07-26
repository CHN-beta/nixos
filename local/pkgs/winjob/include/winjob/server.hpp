# pragma once
# include <string>
# include <functional>
# include <optional>

namespace winjob
{
  class Server
  {
    public: Server(unsigned port, std::function<std::optional<std::string>(std::string)>);
    public: ~Server();
  };
}
