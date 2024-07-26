# pragma once
# include <string>
# include <vector>
# include <chrono>

namespace winjob
{
  enum class JobStatus { Pending, Starting, Running, Done, Exit, Canceled, Lost };
  struct Job
  {
    unsigned Id, Cpu;
    std::string User, Program;
    std::vector<std::string> Args;
    JobStatus Status;
    std::chrono::steady_clock::time_point LastReported, Started, Finished;
  };
}
