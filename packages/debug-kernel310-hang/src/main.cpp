# include <boost/process.hpp>
# include <boost/asio.hpp>
# include <iostream>
# include <format>

int main()
{
  namespace bp = boost::process;
  boost::asio::io_context context;
  boost::filesystem::path actual_program = "/data/gpfs01/jykang/linwei/chn/software/hpcstat/bin/ssh-add";
  auto env = bp::environment::current();
  auto stdout_pipe = std::make_unique<boost::asio::readable_pipe>(context);
  std::string stdout_string;
  bp::process_stdio stdio{ .in = {}, .out = *stdout_pipe, .err = {} };
  auto proc = bp::process
    (context, actual_program, { "-l" }, std::move(stdio), std::move(env));
  proc.wait();
  boost::asio::read(*stdout_pipe, boost::asio::dynamic_buffer(stdout_string));
  std::cout << std::format("{} {}\n", proc.exit_code(), stdout_string);
}
