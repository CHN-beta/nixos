# include <ufo.hpp>

int main(int argc, const char** argv)
{
  using namespace biu::literals;
  if (argc != 3) throw std::runtime_error("Usage: {} task config.yaml"_f(argv[0]));
  if (argv[1] == "fold"s) ufo::fold(argv[2]);
  else if (argv[1] == "unfold"s) ufo::unfold(argv[2]);
  else if (argv[1] == "raman-create-displacement"s) ufo::raman_create_displacement(argv[2]);
  else if (argv[1] == "raman-apply-contribution"s);
  else if (argv[1] == "plot-band"s) ufo::plot_band(argv[2]);
  else if (argv[1] == "plot-point"s) ufo::plot_point(argv[2]);
  else throw std::runtime_error("Unknown task: {}"_f(argv[1]));
}
