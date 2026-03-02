# pragma once
# include <fmt/chrono.h>
# include <biu/logger.hpp>
# include <biu/common.hpp>
# include <biu/format.hpp>
# include <boost/exception/diagnostic_information.hpp>
# ifdef __linux__
# 	include <cpptrace/cpptrace.hpp>
# 	include <cpptrace/from_current.hpp>
# 	include <tgbot/tgbot.h>
# endif

namespace biu
{
	// This should be defined in header
	inline Atomic<Logger::LoggerConfigType_> Logger::LoggerConfig_ = Logger::LoggerConfigType_
	{
		std::experimental::make_observer(&std::clog), nullptr,
# ifdef NDEBUG
		Logger::Level::Info
# else
		Logger::Level::Debug
# endif
	};
	inline void Logger::init(std::experimental::observer_ptr<std::ostream> stream, Level level)
		{ LoggerConfig_ = LoggerConfigType_{stream, nullptr, level}; }
	inline void Logger::init(std::shared_ptr<std::ostream> stream, Level level)
	{
		LoggerConfig_ = LoggerConfigType_
			{std::experimental::make_observer(stream.get()), stream, level};
	}
# ifdef __linux__
	inline Atomic<std::optional<std::pair<std::string, std::string>>> Logger::TelegramConfig_;
	inline void Logger::telegram_init(const std::string& token, const std::string& chat_id)
		{ TelegramConfig_ = std::make_pair(token, chat_id); }
	inline void Logger::telegram_notify(const std::string& message, bool async)
	{
		auto notify = [](const std::string& message)
		{
			auto&& lock = TelegramConfig_.lock();
			TgBot::Bot bot(lock.value()->first);
			bot.getApi().sendMessage(lock.value()->first, message);
		};
		if (async) std::thread(notify, message).detach();
		else notify(message);
	}
# endif
	template <typename T> Logger::ObjectMonitor<T>::ObjectMonitor()
		: CreateTime_{std::chrono::steady_clock::now()}
	{
		Guard guard;
		Objects_.lock()->emplace(this, nameof::nameof_full_type<T>());
		guard.log_<Level::Debug>("create {} at {}."_f(nameof::nameof_full_type<T>(), fmt::ptr(this)));
	}
	template <typename T> Logger::ObjectMonitor<T>::~ObjectMonitor()
	{
		Guard guard;
		guard.log_<Level::Debug>("destroy {} at {} after {} ms."_f
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
	inline Atomic<std::multimap<const void*, std::string_view>> Logger::Objects_;

	template <typename Function> inline void Logger::try_exec(Function&& function)
	{
		Logger::Guard log;
		try { function(); }
		catch (...)
		{
			log.error(boost::current_exception_diagnostic_information());
			if (auto&& lock = LoggerConfig_.lock(); lock->Level >= Logger::Level::Error)
			{
				static_assert(std::same_as<std::size_t, std::uint64_t>);
# ifdef __linux__
				cpptrace::from_current_exception().print(*lock->Stream);
# endif
				*lock->Stream << std::flush;
			}
		}
	}

	inline thread_local unsigned Logger::Guard::Indent_ = 0;
	inline std::size_t Logger::Guard::get_time_ms() const
	{
		return std::chrono::duration_cast<std::chrono::milliseconds>
			(std::chrono::steady_clock::now() - StartTime_).count();
	}
	inline std::size_t Logger::Guard::get_thread_id() const
		{ return std::hash<std::thread::id>{}(std::this_thread::get_id()); }
	template <typename... Param> Logger::Guard::Guard(Param&&... param)
		: StartTime_{std::chrono::steady_clock::now()}
	{
		Indent_++;
		auto&& lock = Threads_.lock();
		if (auto thread_id = get_thread_id(); lock->contains(thread_id)) lock.value()[thread_id]++;
		else lock->emplace(thread_id, 1);
		auto try_format = []<typename T>(T&& value) -> std::string
		{
			if constexpr (fmt::is_formattable<T, char>::value) return "{}"_f(std::forward<T>(value));
			else return "({})"_f(nameof::nameof_full_type<T>());
		};
		if constexpr (sizeof...(Param) > 0)
			log_<Level::Debug>("begin function with {{{}}}."_f(fmt::join({try_format(std::forward<Param>(param))...}, ", ")));
		else log_<Level::Debug>("begin function.");
	}

	Logger::Guard::~Guard()
	{
		log_<Level::Debug>("end function after {} ms."_f(get_time_ms()));
		Indent_--;
		auto&& lock = Threads_.lock();
		if (auto thread_id = get_thread_id(); lock->contains(thread_id))
			{ lock.value()[thread_id]--; if (lock.value()[thread_id] == 0) lock->erase(thread_id); }
		else [[unlikely]]
			error("{:08x} not found in Logger::Threads."_f(thread_id % std::numeric_limits<std::uint64_t>::max()));
	}
	void Logger::Guard::operator()() const { log_<Level::Debug>("reached after {} ms."_f(get_time_ms())); }
	template <Logger::Level L> void Logger::Guard::log_(const std::string& message) const
	{
		if (auto&& lock = LoggerConfig_.lock(); lock->Level >= L)
		{
			static_assert(std::same_as<std::size_t, std::uint64_t>);
			auto time = std::chrono::time_point_cast<std::chrono::milliseconds>(std::chrono::system_clock::now());
# ifdef __linux__
			auto frame = cpptrace::stacktrace::current(2, 1).frames[0];
# 	ifdef BIU_LOGGER_SOURCE_ROOT
			auto source_root = std::string_view(BIU_LOGGER_SOURCE_ROOT "/");
			auto source_file = frame.filename.starts_with(source_root) ?
				frame.filename.substr(source_root.size()) : frame.filename;
# 	else
			auto source_file = frame.filename;
# 	endif
# endif
			*lock->Stream << "[ {:%T} {:02x} {:02} ] {} (at {}:{} {} )\n"_f
			(
				time,
				get_thread_id() % std::numeric_limits<std::uint16_t>::max(),
				Indent_,
				message,
# ifdef __linux__
				source_file.empty() ? "??"s : source_file,
				frame.line.has_value() ? "{}"_f(frame.line.value()) : "??"s,
				frame.symbol
# else
				"??"s, "??"s, "??"s
# endif
			) << std::flush;
		}
	}
	void Logger::Guard::error(const std::string& message) const { log_<Level::Error>(message); }
	void Logger::Guard::info(const std::string& message) const { log_<Level::Info>(message); }
	void Logger::Guard::debug(const std::string& message) const { log_<Level::Debug>(message); }

	template <typename T> T Logger::Guard::rtn(T&& value) const
	{
		log_<Level::Debug>("return {} after {} ms."_f(std::forward<T>(value), get_time_ms()));
		return std::forward<T>(value);
	}

	inline Atomic<std::map<std::size_t, std::size_t>> Logger::Threads_;
}
