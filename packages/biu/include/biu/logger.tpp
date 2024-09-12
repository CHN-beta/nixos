# pragma once
# define BOOST_STACKTRACE_USE_BACKTRACE
# include <fmt/chrono.h>
# include <biu/logger.hpp>
# include <biu/common.hpp>
# include <biu/format.hpp>

namespace biu
{
	template <typename T> Logger::ObjectMonitor<T>::ObjectMonitor()
		: CreateTime_{std::chrono::steady_clock::now()}
	{
		Guard guard;
		Objects_.lock()->emplace(this, nameof::nameof_full_type<T>());
		guard.debug("create {} at {}."_f(nameof::nameof_full_type<T>(), fmt::ptr(this)));
	}
	template <typename T> Logger::ObjectMonitor<T>::~ObjectMonitor()
	{
		Guard guard;
		guard.log<Level::Debug>("destroy {} at {} after {} ms."_f
		(
			nameof::nameof_full_type<T>(), fmt::ptr(this),
			std::chrono::duration_cast<std::chrono::milliseconds>
				(std::chrono::steady_clock::now() - CreateTime_).count()
		));
		auto&& lock = Objects_.lock();
		auto range = lock->equal_range(this);
		for (auto it = range.first; it != range.second; it++) if (it->second == nameof::nameof_full_type<T>())
			{ lock->erase(it); return; }
		guard.error("{} {} not found in Logger::Objects."_f(fmt::ptr(this), nameof::nameof_full_type<T>()));
	}

	template <typename FinalException> Logger::Exception<FinalException>::Exception(const std::string& message)
	{
		Logger::Guard log(message);
		log.print_exception(nameof::nameof_full_type<FinalException>(), message, Stacktrace_, {});
	}

	template <typename... Param> Logger::Guard::Guard(Param&&... param)
		: StartTime_{std::chrono::steady_clock::now()}
	{
		Indent_++;
		auto&& lock = Threads_.lock();
		if (auto thread_id = get_thread_id(); lock->contains(thread_id)) lock.value()[thread_id]++;
		else lock->emplace(thread_id, 1);
		if constexpr (sizeof...(Param) > 0)
			debug("begin function with {{{}}}."_f(fmt::join({"{}"_f(std::forward<Param>(param))...}, ", ")));
		else debug("begin function.");
	}

	Logger::Guard::~Guard()
	{
		debug("end function after {} ms."_f(get_time_ms()));
		Indent_--;
		auto&& lock = Threads_.lock();
		if (auto thread_id = get_thread_id(); lock->contains(thread_id))
			{ lock.value()[thread_id]--; if (lock.value()[thread_id] == 0) lock->erase(thread_id); }
		else [[unlikely]]
			error("{:08x} not found in Logger::Threads."_f(thread_id % std::numeric_limits<std::uint64_t>::max()));
	}
	void Logger::Guard::operator()() const { debug("reached after {} ms."_f(get_time_ms())); }
	template <Logger::Level L> void Logger::Guard::log(const std::string& message) const
	{
		if (auto&& lock = LoggerConfig_.lock(); lock->Level >= L)
		{
			static_assert(std::same_as<std::size_t, std::uint64_t>);
			auto time = std::chrono::system_clock::now();
			boost::stacktrace::stacktrace stack;
			*lock->Stream << "[ {:%Y-%m-%d %H:%M:%S}:{:03} {:08x} {:04} {}:{} {} ] {}\n"_f
			(
				time,
				std::chrono::time_point_cast<std::chrono::milliseconds>(time).time_since_epoch().count() % 1000,
				get_thread_id() % std::numeric_limits<std::uint64_t>::max(),
				Indent_,
				stack[0].source_file().empty() ? "??"s : stack[0].source_file(),
				stack[0].source_line() == 0 ? "??"s : "{}"_f(stack[0].source_line()),
				stack[0].name(),
				message
			) << std::flush;
		}
	}
	void Logger::Guard::error(const std::string& message) const { log<Level::Error>(message); }
	void Logger::Guard::info(const std::string& message) const { log<Level::Info>(message); }
	void Logger::Guard::debug(const std::string& message) const { log<Level::Debug>(message); }

	template <typename T> inline T Logger::Guard::rtn(T&& value) const
	{
		debug("return {} after {} ms."_f(std::forward<T>(value), get_time_ms()));
		return std::forward<T>(value);
	}

	template <typename FinalException> inline void Logger::Guard::print_exception
	(
		const std::string& type, const std::string& message, const boost::stacktrace::stacktrace& stacktrace,
		CalledBy<Exception<FinalException>>
	) const
	{
		log<Level::Error>("{}: {}"_f(type, message));
		if (auto&& lock = LoggerConfig_.lock(); lock->Level >= Logger::Level::Error)
		{
			static_assert(std::same_as<std::size_t, std::uint64_t>);
			for (auto frame : stacktrace)
				*lock->Stream << "\tfrom {}:{} {}\n"_f
				(
					frame.source_file().empty() ? "??"s : frame.source_file(),
					frame.source_line() == 0 ? "??"s : "{}"_f(frame.source_line()),
					frame.name()
				);
			*lock->Stream << std::flush;
		}
	}
}
