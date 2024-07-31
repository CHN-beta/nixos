# pragma once
# include <utility>
# include <biu/smartref.hpp>

namespace biu
{
	template <typename T> inline SmartRef<T>::SmartRef(T& val) : Ref_(val) {}
	template <typename T> template <typename... Us> requires (std::is_constructible_v<T, Us...>)
		inline SmartRef<T>::SmartRef(Us&&... val)
		: Ptr_(std::make_unique<T>(std::forward<Us>(val)...)), Ref_(*Ptr_) {}
	template <typename T> inline T& SmartRef<T>::operator*() {return Ref_;}
	template <typename T> inline T* SmartRef<T>::operator->() {return &Ref_;}
}
