# include <fmt/chrono.h>
# include <biu.hpp>

namespace biu
{
	concurrencpp::generator<std::pair<std::string_view, std::sregex_iterator>> string::find
		(SmartRef<const std::string> data, SmartRef<const std::regex> regex)
	{
		Logger::Guard log;
		std::string::const_iterator unmatched_prefix_begin = data->cbegin(), unmatched_prefix_end;
		std::sregex_iterator regit;
		while (true)
		{
			if (regit == std::sregex_iterator{})
				regit = std::sregex_iterator{data->begin(), data->end(), *regex};
			else
				regit++;
			if (regit == std::sregex_iterator{})
			{
				unmatched_prefix_end = data->cend();
				log.log<Logger::Level::Debug>("distance: {}"_f(std::distance(unmatched_prefix_begin, unmatched_prefix_end)));
			}
			else
				unmatched_prefix_end = (*regit)[0].first;
			co_yield
			{
				std::string_view
				{
					&*unmatched_prefix_begin,
					static_cast<std::size_t>(std::distance(unmatched_prefix_begin, unmatched_prefix_end))
				},
				regit
			};
			if (regit == std::sregex_iterator{})
				break;
			unmatched_prefix_begin = (*regit)[0].second;
		}
	}

	std::string string::replace
		(const std::string& data, const std::regex& regex, std::function<std::string(const std::smatch&)> function)
	{
		Logger::Guard log;
		std::string result;
		for (auto matched : find(data, regex))
		{
			result.append(matched.first);
			if (matched.second != std::sregex_iterator{})
				result.append(function(*matched.second));
		}
		return result;
	}
}
