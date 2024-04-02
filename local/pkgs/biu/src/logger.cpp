# include <tgbot/tgbot.h>
# include <biu.hpp>

namespace biu
{
	Atomic<std::optional<typename Logger::LoggerConfigType_>, false> Logger::LoggerConfig_;
	void Logger::init(std::experimental::observer_ptr<std::ostream> stream, Level level)
	{
		auto&& lock = LoggerConfig_.lock();
		lock->emplace(stream, nullptr, level);
	}
	void Logger::init(std::shared_ptr<std::ostream> stream, Level level)
	{
		auto&& lock = LoggerConfig_.lock();
		lock->emplace(std::experimental::make_observer(stream.get()), stream, level);
	}

	Atomic<std::optional<std::pair<std::string, std::string>>, false> Logger::TelegramConfig_;
	void Logger::telegram_init(const std::string& token, const std::string& chat_id)
		{TelegramConfig_ = std::make_pair(token, chat_id);}
	void Logger::telegram_notify(const std::string& message)
	{
		if (auto&& lock = TelegramConfig_.lock(); *lock)
		{
			TgBot::Bot bot{lock.value()->first};
			bot.getApi().sendMessage(lock.value()->first, message);
		}
	}
	void Logger::telegram_notify_async(const std::string& message)
		{std::thread{Logger::telegram_notify, message}.detach();}

	Atomic<std::multimap<const void*, std::string_view>, false> Logger::Objects_;

	thread_local unsigned Logger::Guard::Indent_ = 0;
	Atomic<std::map<std::size_t, std::size_t>, false> Logger::Threads_;
}
