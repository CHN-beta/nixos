# pragma once
# include <winjob/job.hpp>
# include <boost/asio.hpp>
# include <map>
# include <thread>

namespace winjob
{
  class Scheduler
  {
    public: Scheduler(unsigned cpu);
    public: ~Scheduler();
    public: std::vector<unsigned> submit(std::vector<Job> jobs);
    public: void cancel(std::vector<unsigned> jobs);
    public: std::vector<bool> run(std::vector<unsigned> jobs);
    public: std::vector<bool> refresh(std::vector<unsigned> jobs);
    public: std::vector<Job> status();

    protected: unsigned MaxCpu_, UsedCpu_ = 0;
    protected: std::multimap<JobStatus, Job> Jobs_;
    protected: boost::asio::io_context Context_;
    protected: boost::asio::steady_timer Timer_;
    protected: bool Destructing_ = false;
    protected: std::jthread Executor_;
    protected: unsigned NextId_ = 0;
  };
}
