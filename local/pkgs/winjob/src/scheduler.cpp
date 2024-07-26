# include <winjob/scheduler.hpp>
# include <set>

namespace winjob
{
  using namespace std::literals;
  Scheduler::Scheduler(unsigned cpu)
    : MaxCpu_(cpu), Timer_(Context_, 1s), Executor_([&] { Context_.run(); })
  {
    Timer_.async_wait([&, this](boost::system::error_code)
    {
      // do not run again if destructing
      if (Destructing_) return;

      // check if any job is outdated
      std::vector<Job> outdated;
      auto now = std::chrono::steady_clock::now();
      for (auto it = Jobs_.begin(); it != Jobs_.end();)
        if
        (
          std::set{JobStatus::Pending, JobStatus::Starting, JobStatus::Running}.contains(it->first)
            && now - it->second.LastReported > std::chrono::seconds(30)
        )
        {
          if (std::set{JobStatus::Starting, JobStatus::Running}.contains(it->first))
            UsedCpu_ -= it->second.Cpu;
          outdated.push_back(it->second);
          outdated.back().Status = JobStatus::Lost;
          it = Jobs_.erase(it);
        }
        else ++it;
      for (auto& job : outdated) Jobs_.insert({JobStatus::Lost, job});

      // schedule next check
      Timer_.expires_at(Timer_.expiry() + 1s);
    });
  }
  Scheduler::~Scheduler() { Destructing_ = true; Executor_.join(); }
  std::vector<unsigned> Scheduler::submit(std::vector<Job> jobs)
  {
    std::vector<unsigned> ids;
    boost::asio::dispatch(Context_, [&, this]
    {
      for (auto& job : jobs)
      {
        job.Id = NextId_++;
        job.Status = JobStatus::Pending;
        job.LastReported = std::chrono::steady_clock::now();
        Jobs_.insert({JobStatus::Pending, job});
        ids.push_back(job.Id);
      }
    });
    return ids;
  }
  void Scheduler::cancel(unsigned id) {}
  bool Scheduler::run(unsigned id) {}
  std::vector<Job> Scheduler::status() {}
}
