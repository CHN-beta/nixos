# include <tgbot/tgbot.h>
# include <biu.hpp>

namespace biu
{
	Atomic<Logger::LoggerConfigType_> Logger::LoggerConfig_ = Logger::LoggerConfigType_
	{
		std::experimental::make_observer(&std::clog), nullptr,
# ifdef NDEBUG
		Logger::Level::Info
# else
		Logger::Level::Debug
# endif
	};
	void Logger::init(std::experimental::observer_ptr<std::ostream> stream, Level level)
		{ LoggerConfig_ = LoggerConfigType_{stream, nullptr, level}; }
	void Logger::init(std::shared_ptr<std::ostream> stream, Level level)
	{
		LoggerConfig_ = LoggerConfigType_
			{std::experimental::make_observer(stream.get()), stream, level};
	}

	Atomic<std::optional<std::pair<std::string, std::string>>> Logger::TelegramConfig_;
	void Logger::telegram_init(const std::string& token, const std::string& chat_id)
		{ TelegramConfig_ = std::make_pair(token, chat_id); }
	void Logger::telegram_notify(const std::string& message, bool async)
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

	Atomic<std::multimap<const void*, std::string_view>> Logger::Objects_;

	thread_local unsigned Logger::Guard::Indent_ = 0;
	std::size_t Logger::Guard::get_time_ms() const
	{
		return std::chrono::duration_cast<std::chrono::milliseconds>
			(std::chrono::steady_clock::now() - StartTime_).count();
	}
	std::size_t Logger::Guard::get_thread_id() const
		{ return std::hash<std::thread::id>{}(std::this_thread::get_id()); }

	Atomic<std::map<std::size_t, std::size_t>> Logger::Threads_;
}
