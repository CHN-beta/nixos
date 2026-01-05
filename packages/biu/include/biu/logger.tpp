# pragma once
# include <fmt/chrono.h>
# include <tgbot/tgbot.h>
# include <biu/logger.hpp>
# include <biu/common.hpp>
# include <biu/format.hpp>
# include <boost/exception/diagnostic_information.hpp>

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
	inline Atomic<std::multimap<const void*, std::string_view>> Logger::Objects_;

	template <typename Function> inline void Logger::try_exec(Function&& function)
	{
		Logger::Guard log;
		try { function(); }
		catch (...)
		{
			log.error(boost::current_exception_diagnostic_information());
			log.print_exception
				(std::nullopt, boost::stacktrace::stacktrace::from_current_exception());
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
			debug("begin function with {{{}}}."_f(fmt::join({try_format(std::forward<Param>(param))...}, ", ")));
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
			auto time = std::chrono::time_point_cast<std::chrono::milliseconds>(std::chrono::system_clock::now());
			boost::stacktrace::stacktrace stack;
# 	ifdef BIU_LOGGER_SOURCE_ROOT
			auto source_root = std::string_view(BIU_LOGGER_SOURCE_ROOT "/");
			auto source_file = stack[0].source_file().starts_with(source_root) ?
				stack[0].source_file().substr(source_root.size()) : stack[0].source_file();
# 	else
			auto source_file = stack[0].source_file();
# 	endif
			*lock->Stream << "[ {:%T} {:02x} {:02} ] {} (at {}:{} {} )\n"_f
			(
				time,
				get_thread_id() % std::numeric_limits<std::uint16_t>::max(),
				Indent_,
				message,
				source_file.empty() ? "??"s : source_file,
				stack[0].source_line() == 0 ? "??"s : "{}"_f(stack[0].source_line()),
				stack[0].name()
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

	inline void Logger::Guard::print_exception
	(
		std::optional<std::pair<std::string, std::string>> type_and_message,
		const boost::stacktrace::stacktrace& stacktrace
	) const
	{
		if (type_and_message) log<Level::Error>("{}: {}"_f(type_and_message->first, type_and_message->second));
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

	inline Atomic<std::map<std::size_t, std::size_t>> Logger::Threads_;
}
