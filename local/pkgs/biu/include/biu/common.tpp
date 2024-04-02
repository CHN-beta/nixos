# pragma once
# include <boost/functional/hash.hpp>
# include <biu/common.hpp>

namespace biu
{
	inline void unused(auto&&...) {}
	inline std::size_t hash(auto&&... objs)
	{
		std::size_t result = 0;
		(boost::hash_combine(result, objs), ...);
		return result;
	}

	template <typename String> inline constexpr bool CaseInsensitiveStringLessComparator::operator()
		(const String& s1, const String& s2) const
	{
		return std::lexicographical_compare
		(
			s1.begin(), s1.end(), s2.begin(), s2.end(),
			[](char c1, char c2){return std::tolower(c1) < std::tolower(c2);}
		);
	}
}