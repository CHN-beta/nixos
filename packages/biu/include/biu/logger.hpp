# pragma once
# include <map>
# include <boost/stacktrace.hpp>
# include <biu/atomic/nolog.hpp>

namespace biu
{
	class Logger
	{
		// All the member function corresponding to stacktrace should be inlined
		// All the public function (including public function of member class) should be thread safe.

		public: Logger() = delete;

		// Setup output stream and log level in a thread-safe way
		public: enum class Level
		{
			None,
			Error,
			Access,
			Info,
			Debug
		};
		protected: struct LoggerConfigType_
		{
			std::experimental::observer_ptr<std::ostream> Stream;
			std::shared_ptr<std::ostream> StreamStorage;
			Logger::Level Level;
		};
		protected: static Atomic<std::optional<LoggerConfigType_>, false> LoggerConfig_;
		public: static void init(std::experimental::observer_ptr<std::ostream> stream, Level level);
		public: static void init(std::shared_ptr<std::ostream> stream, Level level);

		// Send a telegram message if token and chat id are set, all the functions are thread-safe
		protected: static Atomic<std::optional<std::pair<std::string, std::string>>, false> TelegramConfig_;
		public: static void telegram_init(const std::string& token, const std::string& chat_id);
		public: static void telegram_notify(const std::string& message);
		public: static void telegram_notify_async(const std::string& message);

		// Monitor the lifetime of an object
		// usage: struct my_class : protected Logger::ObjectMonitor<my_class> {}
		public: template <typename T> class ObjectMonitor
		{
			protected: const std::chrono::time_point<std::chrono::steady_clock> CreateTime_;

			// call log<Debug>("create {type} at {address}.");
			protected: [[gnu::always_inline]] ObjectMonitor();

			// call log<Debug>("destroy {type} at {address} after {duration} ms.");
			protected: [[gnu::always_inline]] virtual ~ObjectMonitor();
		};
		template <typename T> friend class ObjectMonitor;

		// List of objects that is being monitored by ObjectMonitor, {address, type}
		protected: static Atomic<std::multimap<const void*, std::string_view>, false> Objects_;

		public: template <typename FinalException> class Exception : public std::exception
		{
			protected: const std::string Message_;
			protected: const boost::stacktrace::stacktrace Stacktrace_;

			public: explicit Exception(const std::string& message);
			public: const char* what() const noexcept final {return Message_.c_str();}
		};

		// Monitor the start and end of a function, as well as corresponding thread.
		// This object should be construct at the beginning of the function, and should never be passed to another
		// function or thread.
		public: class Guard
		{
			protected: thread_local static unsigned Indent_;
			protected: const std::chrono::time_point<std::chrono::steady_clock> StartTime_;

			// if sizeof...(Param) > 0, call log<Debug>("begin function with {arguments}.");
			// else call log<Debug>("begin function.");
			public: template <typename... Param> [[gnu::always_inline]] explicit Guard(Param&&... param);

			// call log<Debug>("end function after {duration} ms.")
			public: [[gnu::always_inline]] virtual ~Guard();

			// call log<Debug>("reached after {duration} ms.")
			public: [[gnu::always_inline]] void operator()() const;

			// call log<Debug>("return {return} after {duration} ms.")
			public: template <typename T> [[gnu::always_inline]] T rtn(T&& value) const;

			// print the following message if LoggerConfig_ is set and the level is higher than the level of the
			// LoggerConfig_
			// [ {time} {thread} {indent} {filename}:{line} {function_name} ] {message}
			public: template <Level L> [[gnu::always_inline]] void log(const std::string& message) const;

			public: template <typename FinalException> [[gnu::always_inline]] void print_exception
			(
				const std::string& type, const std::string& message, const boost::stacktrace::stacktrace& stacktrace,
				CalledBy<Exception<FinalException>>
			) const;
		};
		friend class Guard;

		// list of threads which is being monitored by Guard and number of Guard created in this thread so far
		protected: static Atomic<std::map<std::size_t, std::size_t>, false> Threads_;
	};
}
