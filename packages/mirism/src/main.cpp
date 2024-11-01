# include <biu.hpp>
# include <httplib.h>

int main()
{
  using namespace biu::literals;

  httplib::SSLServer srv("/var/lib/acme/debug.mirism.one/fullchain.pem",
    "/var/lib/acme/debug.mirism.one/key.pem");
  srv.Get("/", [](const httplib::Request& req, httplib::Response& res) {
    std::cout << "{}"_f(req.headers) << std::endl;
    httplib::Client cli("https://github.com");
    auto upstream_res = cli.Get("/");
    res.headers = upstream_res->headers;
    res.body = upstream_res->body;
    res.status = upstream_res->status;
    std::cout << "{}"_f(upstream_res->headers) << std::endl;
    std::cout << "{}"_f(upstream_res->body) << std::endl;
  });
  srv.listen("127.0.0.1", 15641);
}
