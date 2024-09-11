# include <ufo.hpp>

int main(int argc, const char** argv)
{
  if (argc != 3)
    throw std::runtime_error(fmt::format("Usage: {} task config.yaml", argv[0]));
  if (argv[1] == std::string("fold"))
    ufo::fold(argv[2]);
  else if (argv[1] == std::string("unfold"))
    ufo::unfold(argv[2]);
  // else if (argv[1] == std::string("plot"))
  //   ufo::PlotSolver{argv[2]}();
  else
    throw std::runtime_error(fmt::format("Unknown task: {}", argv[1]));
}
