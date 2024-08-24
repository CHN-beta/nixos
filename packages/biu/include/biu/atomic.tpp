# pragma once
# include <biu/atomic.hpp>

namespace biu
{
	template <DecayedType ValueType> template <bool Const> template <bool OtherConst>
		Atomic<ValueType>::Guard<Const>::Guard(Guard<OtherConst>&& other) requires (Const || !OtherConst)
		: Lock_{std::move(other.Lock_)}, Value_{std::move(other.Value_)} {}
	template <DecayedType ValueType> template <bool Const> Atomic<ValueType>::Guard<Const>::Guard
		(decltype(Lock_)&& lock, decltype(Value_) value, CalledBy<Atomic<ValueType>>)
		: Lock_{std::move(lock)}, Value_{value} {}
	template <DecayedType ValueType> template <bool Const> Atomic<ValueType>::Guard<Const>::~Guard()
		{ if constexpr (!Const) Value_->ConditionVariable_.notify_all(); }

	template <DecayedType ValueType> template <bool Const> std::conditional_t<Const, const ValueType&, ValueType&>
		Atomic<ValueType>::Guard<Const>::operator*() const&
		{ return Value_->Value_; }
	template <DecayedType ValueType> template <bool Const> std::conditional_t<Const, const ValueType*, ValueType*>
		Atomic<ValueType>::Guard<Const>::operator->() const&
		{ return &Value_->Value_; }
	template <DecayedType ValueType> template <bool Const> std::conditional_t<Const, const ValueType&, ValueType&>
		Atomic<ValueType>::Guard<Const>::value() const&
		{ return Value_->Value_; }

	template <DecayedType ValueType> Atomic<ValueType>::Atomic(auto&& value)
		: Value_{std::forward<decltype(value)>(value)} {}
	template <DecayedType ValueType> Atomic<ValueType>& Atomic<ValueType>::operator=(auto&& value)
	{
		std::scoped_lock lock(Mutex_);
		Value_ = std::forward<decltype(value)>(value);
		ConditionVariable_.notify_all();
		return *this;
	}

	template <DecayedType ValueType> ValueType Atomic<ValueType>::get(this auto&& self)
		{ std::scoped_lock lock(self.Mutex_); return self.Value_; }
	template <DecayedType ValueType> Atomic<ValueType>::operator ValueType(this auto&& self)
		{ return self.get(); }

	template <DecayedType ValueType> template <bool Throw> auto Atomic<ValueType>::lock_
		(this auto&& self, auto&& condition_function, auto timeout)
	{
		if constexpr (Nullptr<decltype(condition_function)>)
			return Guard<std::is_const_v<decltype(self)>>
				(std::unique_lock{self.Mutex_}, std::experimental::make_observer(&self), {});
		else if constexpr (Nullptr<decltype(timeout)>)
		{
			std::unique_lock lock(self.Mutex_);
			self.ConditionVariable_.wait(lock, [&]
				{ return std::forward<decltype(condition_function)>(condition_function)(std::as_const(self.Value_)); });
			return Guard<std::is_const_v<decltype(self)>>(std::move(lock), std::experimental::make_observer(&self), {});
		}
		else
		{
			std::unique_lock lock(self.Mutex_);
			if (!self.ConditionVariable_.wait_for(lock, timeout, [&]
				{ return std::forward<decltype(condition_function)>(condition_function)(std::as_const(self.Value_)); }))
			{
				if constexpr (Throw) throw std::runtime_error("Timeout");
				else return std::optional<Guard<std::is_const_v<decltype(self)>>>();
			}
			else return std::optional(Guard<std::is_const_v<decltype(self)>>
				(std::move(lock), std::experimental::make_observer(&self), {}));
		}
	}

	template <DecayedType ValueType> template <bool NoReturn> decltype(auto) Atomic<ValueType>::apply
		(this auto&& self, auto&& function, auto&& condition_function, auto&& timeout)
	{
		using function_return_type = std::invoke_result_t<decltype(function), MoveQualifiers<decltype(self), ValueType>>;
		auto&& lock = std::forward<decltype(self)>(self).template lock_<NoReturn>
			(std::forward<decltype(condition_function)>(condition_function), timeout);
		// 如果得到的是 optional
		if constexpr (SpecializationOf<std::remove_cvref_t<decltype(lock)>, std::optional>)
			// 如果超时了，返回 false 或者对应的 nullopt
			if (!lock)
				if constexpr (std::is_void_v<function_return_type>) return false;
				else return std::optional<function_return_type>();
			// 否则，执行函数
			else
			  if constexpr (std::is_void_v<function_return_type>)
				{
					std::forward<decltype(function)>(function)
						(std::forward<MoveQualifiers<decltype(self), ValueType>>(self.Value_));
					// 如果函数本身返回 void 并且不可能超时，返回 *this，否则返回 true
					if constexpr (Nullptr<decltype(condition_function)> || Nullptr<decltype(timeout)>)
						return std::forward<decltype(self)>(self);
					else return true;
				}
				else
				{
					auto&& result = std::forward<decltype(function)>(function)
						(std::forward<MoveQualifiers<decltype(self), ValueType>>(self.Value_));
					return std::make_optional(std::forward<decltype(result)>(result));
				}
		// 否则，说明不可能超时，返回函数的返回值或者 *this
		else
			if constexpr (std::is_void_v<function_return_type>)
			{
				std::forward<decltype(function)>(function)
					(std::forward<MoveQualifiers<decltype(self), ValueType>>(self.Value_));
				return std::forward<decltype(self)>(self);
			}
			else
				return std::forward<decltype(function)>(function)
					(std::forward<MoveQualifiers<decltype(self), ValueType>>(self.Value_));
	}
	template <DecayedType ValueType> template <bool NoReturn> decltype(auto) Atomic<ValueType>::apply
		(this auto&& self, auto&& function, auto&& condition_function)
	{
		return std::forward<decltype(self)>(self).template apply<NoReturn>
		(
			std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function),
			nullptr
		);
	}
	template <DecayedType ValueType> template <bool NoReturn> decltype(auto) Atomic<ValueType>::apply
		(this auto&& self, auto&& function)
	{
		return std::forward<decltype(self)>(self).template apply<NoReturn>
			(std::forward<decltype(function)>(function), nullptr, nullptr);
	}

	template <DecayedType ValueType> template <bool NoReturn> decltype(auto) Atomic<ValueType>::wait
		(this auto&& self, auto&& condition_function, auto timeout)
	{
		auto result = std::forward<decltype(self)>(self).template lock_<NoReturn>
			(std::forward<decltype(condition_function)>(condition_function), timeout);
		if constexpr (SpecializationOf<decltype(result), std::optional>) return result.has_value();
		else return std::forward<decltype(result)>(result);
	}
	template <DecayedType ValueType> template <bool NoReturn> decltype(auto) Atomic<ValueType>::wait
		(this auto&& self, auto&& condition_function)
	{
		return std::forward<decltype(self)>(self).template wait<NoReturn>
			(std::forward<decltype(condition_function)>(condition_function), nullptr);
	}

	template <DecayedType ValueType> template <bool Throw> auto Atomic<ValueType>::lock
		(this auto&& self, auto&& condition_function, auto timeout)
	{
		// self 不能是右值引用
		static_assert(!std::is_rvalue_reference_v<decltype(self)>, "rvalue atomic cannot be locked");
		return std::forward<decltype(self)>(self).template lock_<Throw>
			(std::forward<decltype(condition_function)>(condition_function), timeout);
	}
	template <DecayedType ValueType> template <bool Throw> auto Atomic<ValueType>::lock
		(this auto&& self, auto&& condition_function)
	{
		return std::forward<decltype(self)>(self).template lock<Throw>
			(std::forward<decltype(condition_function)>(condition_function), nullptr);
	}
	template <DecayedType ValueType> template <bool Throw> auto Atomic<ValueType>::lock(this auto&& self)
		{ return std::forward<decltype(self)>(self).template lock<Throw>(nullptr, nullptr); }
}
