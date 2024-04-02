# pragma once

namespace biu
{
	template <typename AllowedType> class CalledBy
	{
		protected: CalledBy() = default;
		friend AllowedType;
	};
}
