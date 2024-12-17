# include <biu.hpp>
int main()
{
  biu::Logger::Guard log("test", nullptr, std::ofstream());
}
