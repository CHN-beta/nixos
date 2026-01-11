# include <biu.hpp>
int main()
{
  biu::Logger::Guard log("test", nullptr, std::ofstream());
  log.info("hello world");
  return 0;
}
