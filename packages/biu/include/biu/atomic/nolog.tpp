# pragma once
# include <biu/atomic/nolog.hpp>

namespace biu
{
	template <DecayedType ValueType> detail_::AtomicBase<ValueType, false>::AtomicBase(const ValueType& value)
		: Value_{value} {}
	template <DecayedType ValueType> detail_::AtomicBase<ValueType, false>::AtomicBase(ValueType&& value)
		: Value_{std::move(value)} {}

	template <DecayedType ValueType>
		detail_::AtomicBase<ValueType, false>::TimeoutException::TimeoutException(std::string)
		: Message_{"TimeoutException"} {}
	template <DecayedType ValueType>
		const char* detail_::AtomicBase<ValueType, false>::TimeoutException::what() const noexcept
		{return Message_.c_str();}

	template <DecayedType ValueType>
		template <bool ReturnFunctionResult, typename ConditionFunction, typename Duration, bool Nothrow>
		auto detail_::AtomicBase<ValueType, false>::apply_
			(auto&& atomic, auto&& function, ConditionFunction&& condition_function, Duration timeout)
		-> ApplyReturnType_
			<decltype(function), decltype(atomic), ReturnFunctionResult, ConditionFunction, Duration, Nothrow>
		requires ApplyConstraint_<decltype(function), decltype(atomic), ConditionFunction, Duration>
	{
		std::unique_lock lock{atomic.Mutex_};

		// try to meet the condition
		if constexpr (!std::is_null_pointer_v<ConditionFunction>)
		{
			if constexpr (std::is_null_pointer_v<Duration>)
				atomic.ConditionVariable_.wait(lock, [&]
					{return std::forward<ConditionFunction>(condition_function)(std::as_const(atomic.Value_));});
			else if (!atomic.ConditionVariable_.wait_for(lock, timeout, [&]
				{return std::forward<ConditionFunction>(condition_function)(std::as_const(atomic.Value_));}))
			{
				if constexpr (Nothrow)
				{
					if constexpr
						(ReturnFunctionResult && !std::is_void_v<std::invoke_result_t<decltype(function), ValueType>>)
						return std::nullopt;
					else return false;
				}
				else throw TimeoutException{};
			}
		}

		// apply the function and return
		if constexpr (ReturnFunctionResult && !std::is_void_v<std::invoke_result_t<decltype(function), ValueType>>)
		{
			auto&& result = std::forward<decltype(function)>(function)
				(static_cast<MoveQualifiers<decltype(atomic), ValueType>&&>(atomic.Value_));
			if constexpr (!std::is_const_v<decltype(atomic)>) atomic.ConditionVariable_.notify_all();
			return std::forward<decltype(result)>(result);
		}
		else
		{
			std::forward<decltype(function)>(function)
				(static_cast<MoveQualifiers<decltype(atomic), ValueType>&&>(atomic.Value_));
			if constexpr (!std::is_const_v<decltype(atomic)>) atomic.ConditionVariable_.notify_all();
			if constexpr (ReturnFunctionResult && std::is_void_v<std::invoke_result_t<decltype(function), ValueType>>)
				return;
			else return std::forward<decltype(atomic)>(atomic);
		}
	}

	template <DecayedType ValueType> template <bool Nothrow, typename Duration>
		auto detail_::AtomicBase<ValueType, false>::wait_(auto&& atomic, auto&& condition_function, Duration timeout)
		-> WaitReturnType_<decltype(atomic), decltype(condition_function), Duration, Nothrow>
		requires WaitConstraint_<decltype(condition_function), Duration>
	{
		std::unique_lock lock{atomic.Mutex_};

		if constexpr (std::is_null_pointer_v<Duration>)
		{
			atomic.ConditionVariable_.wait(lock, [&]
				{return std::forward<decltype(condition_function)>(condition_function)(std::as_const(atomic.Value_));});
			return std::forward<decltype(atomic)>(atomic);
		}
		else
		{
			if (!atomic.ConditionVariable_.wait_for(lock, timeout, [&]
				{return std::forward<decltype(condition_function)>(condition_function)(std::as_const(atomic.Value_));}))
			{
				if constexpr (Nothrow) return false;
				else throw TimeoutException{};
			}
			else
			{
				if constexpr (Nothrow) return true;
				else return std::forward<decltype(atomic)>(atomic);
			}
		}
	}

	template <DecayedType ValueType> template <bool Nothrow, typename ConditionFunction, typename Duration>
		auto detail_::AtomicBase<ValueType, false>::lock_
		(auto&& atomic, ConditionFunction&& condition_function, Duration timeout)
		-> LockReturnType_<decltype(atomic), Duration, Nothrow> requires LockConstraint_<ConditionFunction, Duration>
	{
		if constexpr (std::is_null_pointer_v<ConditionFunction>)
			return {std::unique_lock{atomic.Mutex_}, std::experimental::make_observer(&atomic), {}};
		else if constexpr (std::is_null_pointer_v<Duration>)
		{
			std::unique_lock lock{atomic.Mutex_};
			atomic.ConditionVariable_.wait(lock, [&]
				{return std::forward<ConditionFunction>(condition_function)(std::as_const(atomic.Value_));});
			return {std::move(lock), std::experimental::make_observer(&atomic), {}};
		}
		else
		{
			std::unique_lock lock{atomic.Mutex_};
			if (!atomic.ConditionVariable_.wait_for(lock, timeout, [&]
				{return std::forward<ConditionFunction>(condition_function)(std::as_const(atomic.Value_));}))
			{
				if constexpr (Nothrow) return std::nullopt;
				else throw TimeoutException{};
			}
			else
				return {{std::move(lock), std::experimental::make_observer(&atomic), {}}};
		}
	}

	template <DecayedType ValueType, bool UseLogger> Atomic<ValueType, UseLogger>::Atomic(const ValueType& value)
		: detail_::AtomicBase<ValueType, UseLogger>{value} {}
	template <DecayedType ValueType, bool UseLogger> Atomic<ValueType, UseLogger>::Atomic(ValueType&& value)
		: detail_::AtomicBase<ValueType, UseLogger>{std::move(value)} {}
	template <DecayedType ValueType, bool UseLogger> template <bool OtherUseLogger>
		Atomic<ValueType, UseLogger>::Atomic(const Atomic<ValueType, OtherUseLogger>& other)
		: detail_::AtomicBase<ValueType, UseLogger>{other} {}
	template <DecayedType ValueType, bool UseLogger> template <bool OtherUseLogger>
		Atomic<ValueType, UseLogger>::Atomic(Atomic<ValueType, OtherUseLogger>&& other)
		: detail_::AtomicBase<ValueType, UseLogger>{std::move(other)} {}
	template <DecayedType ValueType, bool UseLogger>
		Atomic<ValueType, UseLogger>& Atomic<ValueType, UseLogger>::operator=(const ValueType& value)
	{
		std::scoped_lock lock{DeepBase_::Mutex_};
		DeepBase_::Value_ = value;
		DeepBase_::ConditionVariable_.notify_all();
		return *this;
	}
	template <DecayedType ValueType, bool UseLogger>
		Atomic<ValueType, UseLogger>& Atomic<ValueType, UseLogger>::operator=(ValueType&& value)
	{
		std::scoped_lock lock{DeepBase_::Mutex_};
		DeepBase_::Value_ = std::move(value);
		DeepBase_::ConditionVariable_.notify_all();
		return *this;
	}
	template <DecayedType ValueType, bool UseLogger> template <bool OtherUseLogger>
		Atomic<ValueType, UseLogger>& operator=(const Atomic<ValueType, OtherUseLogger>& other)
	{
		std::scoped_lock lock{DeepBase_::Mutex_};
		DeepBase_::Value_ = value;
		DeepBase_::ConditionVariable_.notify_all();
		return *this;
	}
	template <DecayedType ValueType, bool UseLogger> template <bool OtherUseLogger>
		Atomic<ValueType, UseLogger>& operator=(Atomic<ValueType, OtherUseLogger>&& other)
	{
		std::scoped_lock lock{DeepBase_::Mutex_};
		DeepBase_::Value_ = std::move(value);
		DeepBase_::ConditionVariable_.notify_all();
		return *this;
	}
	template <DecayedType ValueType, bool UseLogger> ValueType Atomic<ValueType, UseLogger>::get() const&
	{
		std::scoped_lock lock{DeepBase_::Mutex_};
		return DeepBase_::Value_;
	}
	template <DecayedType ValueType, bool UseLogger> ValueType Atomic<ValueType, UseLogger>::get() &&
	{
		std::scoped_lock lock{DeepBase_::Mutex_};
		return std::move(DeepBase_::Value_);
	}
	template <DecayedType ValueType, bool UseLogger> Atomic<ValueType, UseLogger>::operator ValueType() const&
		{return get();}
	template <DecayedType ValueType, bool UseLogger> Atomic<ValueType, UseLogger>::operator ValueType() &&
		{return std::move(*this).get();}

	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function) const&
		-> DeepBase_::template ApplyReturnType_<decltype(function), decltype(*this), ReturnFunctionResult>
		requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this)>
		{return apply_<ReturnFunctionResult>(*this, std::forward<decltype(function)>(function));}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function) &
		-> DeepBase_::template ApplyReturnType_<decltype(function), decltype(*this), ReturnFunctionResult>
		requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this)>
		{return apply_<ReturnFunctionResult>(*this, std::forward<decltype(function)>(function));}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function) &&
		-> DeepBase_::template ApplyReturnType_<decltype(function), decltype(*this), ReturnFunctionResult>
		requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this)>
		{return apply_<ReturnFunctionResult>(std::move(*this), std::forward<decltype(function)>(function));}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function, auto&& condition_function) const&
		-> DeepBase_::template ApplyReturnType_
			<decltype(function), decltype(*this), ReturnFunctionResult, decltype(condition_function)>
		requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this), decltype(condition_function)>
	{
		return apply_<ReturnFunctionResult>
		(
			*this, std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function)
		);
	}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function, auto&& condition_function) &
		-> DeepBase_::template ApplyReturnType_
			<decltype(function), decltype(*this), ReturnFunctionResult, decltype(condition_function)>
		requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this), decltype(condition_function)>
	{
		return apply_<ReturnFunctionResult>
		(
			*this, std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function)
		);
	}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function, auto&& condition_function) &&
		-> DeepBase_::template ApplyReturnType_
			<decltype(function), decltype(*this), ReturnFunctionResult, decltype(condition_function)>
		requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this), decltype(condition_function)>
	{
		return apply_<ReturnFunctionResult>
		(
			std::move(*this), std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function)
		);
	}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult, bool Nothrow>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function, auto&& condition_function, auto timeout) const&
		-> DeepBase_::template ApplyReturnType_
		<
			decltype(function), decltype(*this), ReturnFunctionResult,
			decltype(condition_function), decltype(timeout), Nothrow
		> requires DeepBase_::template ApplyConstraint_
			<decltype(function), decltype(*this), decltype(condition_function), decltype(timeout)>
	{
		return apply_<ReturnFunctionResult, Nothrow>
		(
			*this, std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function), timeout
		);
	}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult, bool Nothrow>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function, auto&& condition_function, auto timeout) &
		-> DeepBase_::template ApplyReturnType_
		<
			decltype(function), decltype(*this), ReturnFunctionResult,
			decltype(condition_function), decltype(timeout), Nothrow
		> requires DeepBase_::template ApplyConstraint_
			<decltype(function), decltype(*this), decltype(condition_function), decltype(timeout)>
	{
		return apply_<ReturnFunctionResult, Nothrow>
		(
			*this, std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function), timeout
		);
	}
	template <DecayedType ValueType, bool UseLogger> template <bool ReturnFunctionResult, bool Nothrow>
		auto Atomic<ValueType, UseLogger>::apply(auto&& function, auto&& condition_function, auto timeout) &&
		-> DeepBase_::template ApplyReturnType_
		<
			decltype(function), decltype(*this), ReturnFunctionResult,
			decltype(condition_function), decltype(timeout), Nothrow
		> requires DeepBase_::template ApplyConstraint_
			<decltype(function), decltype(*this), decltype(condition_function), decltype(timeout)>
	{
		return apply_<ReturnFunctionResult, Nothrow>
		(
			std::move(*this), std::forward<decltype(function)>(function),
			std::forward<decltype(condition_function)>(condition_function), timeout
		);
	}

	template <DecayedType ValueType, bool UseLogger>
		auto Atomic<ValueType, UseLogger>::wait(auto&& condition_function) const&
		-> DeepBase_::template WaitReturnType_<decltype(*this), decltype(condition_function)>
		requires DeepBase_::template WaitConstraint_<decltype(condition_function)>
		{return wait_(*this, std::forward<decltype(condition_function)>(condition_function));}
	template <DecayedType ValueType, bool UseLogger>
		auto Atomic<ValueType, UseLogger>::wait(auto&& condition_function) &
		-> DeepBase_::template WaitReturnType_<decltype(*this), decltype(condition_function)>
		requires DeepBase_::template WaitConstraint_<decltype(condition_function)>
		{return wait_(*this, std::forward<decltype(condition_function)>(condition_function));}
	template <DecayedType ValueType, bool UseLogger>
		auto Atomic<ValueType, UseLogger>::wait(auto&& condition_function) &&
		-> DeepBase_::template WaitReturnType_<decltype(*this), decltype(condition_function)>
		requires DeepBase_::template WaitConstraint_<decltype(condition_function)>
		{return wait_(std::move(*this), std::forward<decltype(condition_function)>(condition_function));}
	template <DecayedType ValueType, bool UseLogger> template <bool Nothrow>
		auto Atomic<ValueType, UseLogger>::wait(auto&& condition_function, auto timeout) const&
		-> DeepBase_::template WaitReturnType_
			<decltype(*this), decltype(condition_function), decltype(timeout), Nothrow>
		requires DeepBase_::template WaitConstraint_<decltype(condition_function), decltype(timeout)>
		{return wait_<Nothrow>(*this, std::forward<decltype(condition_function)>(condition_function), timeout);}
	template <DecayedType ValueType, bool UseLogger> template <bool Nothrow>
		auto Atomic<ValueType, UseLogger>::wait(auto&& condition_function, auto timeout) &
		-> DeepBase_::template WaitReturnType_
			<decltype(*this), decltype(condition_function), decltype(timeout), Nothrow>
		requires DeepBase_::template WaitConstraint_<decltype(condition_function), decltype(timeout)>
		{return wait_<Nothrow>(*this, std::forward<decltype(condition_function)>(condition_function), timeout);}
	template <DecayedType ValueType, bool UseLogger> template <bool Nothrow>
		auto Atomic<ValueType, UseLogger>::wait(auto&& condition_function, auto timeout) &&
		-> DeepBase_::template WaitReturnType_
			<decltype(*this), decltype(condition_function), decltype(timeout), Nothrow>
		requires DeepBase_::template WaitConstraint_<decltype(condition_function), decltype(timeout)>
	{
		return wait_<Nothrow>
			(std::move(*this), std::forward<decltype(condition_function)>(condition_function), timeout);
	}

	template <DecayedType ValueType, bool UseLogger> template <bool Const> template <bool OtherConst>
		Atomic<ValueType, UseLogger>::Guard<Const>::Guard(const Guard<OtherConst>& other)
		requires (Const || !OtherConst)
		: Lock_{other.Lock_}, Value_{other.Value_} {}
	template <DecayedType ValueType, bool UseLogger> template <bool Const>
		Atomic<ValueType, UseLogger>::Guard<Const>::Guard
		(decltype(Lock_)&& lock, decltype(Value_) value, CalledBy<detail_::AtomicBase<ValueType, UseLogger>>)
		: Lock_{std::move(lock)}, Value_{value} {}
	template <DecayedType ValueType, bool UseLogger> template <bool Const>
		Atomic<ValueType, UseLogger>::Guard<Const>::~Guard()
		{Value_->ConditionVariable_.notify_all();}

	template <DecayedType ValueType, bool UseLogger> template <bool Const>
		std::conditional_t<Const, const ValueType&, ValueType&>
		Atomic<ValueType, UseLogger>::Guard<Const>::operator*() const&
		{return Value_->Value_;}
	template <DecayedType ValueType, bool UseLogger> template <bool Const>
		std::conditional_t<Const, const ValueType*, ValueType*>
		Atomic<ValueType, UseLogger>::Guard<Const>::operator->() const&
		{return &Value_->Value_;}
	template <DecayedType ValueType, bool UseLogger> template <bool Const>
		std::conditional_t<Const, const ValueType&, ValueType&>
		Atomic<ValueType, UseLogger>::Guard<Const>::value() const&
		{return Value_->Value_;}

	template <DecayedType ValueType, bool UseLogger> auto Atomic<ValueType, UseLogger>::lock() const&
		-> DeepBase_::template LockReturnType_<decltype(*this)> requires DeepBase_::template LockConstraint_<>
		{return lock_(*this);}
	template <DecayedType ValueType, bool UseLogger> auto Atomic<ValueType, UseLogger>::lock() &
		-> DeepBase_::template LockReturnType_<decltype(*this)> requires DeepBase_::template LockConstraint_<>
		{return lock_(*this);}
	template <DecayedType ValueType, bool UseLogger>
		auto Atomic<ValueType, UseLogger>::lock(auto&& condition_function) const&
		-> DeepBase_::template LockReturnType_<decltype(*this), decltype(condition_function)>
		requires DeepBase_::template LockConstraint_<decltype(condition_function)>
		{return lock_(*this, condition_function);}
	template <DecayedType ValueType, bool UseLogger>
		auto Atomic<ValueType, UseLogger>::lock(auto&& condition_function) &
		-> DeepBase_::template LockReturnType_<decltype(*this), decltype(condition_function)>
		requires DeepBase_::template LockConstraint_<decltype(condition_function)>
		{return lock_(*this, condition_function);}
	template <DecayedType ValueType, bool UseLogger> template <bool Nothrow>
		auto Atomic<ValueType, UseLogger>::lock(auto&& condition_function, auto timeout) const&
		-> DeepBase_::template LockReturnType_<decltype(*this), decltype(timeout), Nothrow>
		requires DeepBase_::template LockConstraint_<decltype(condition_function), decltype(timeout)>
		{return lock_<Nothrow>(*this, condition_function, timeout);}
	template <DecayedType ValueType, bool UseLogger> template <bool Nothrow>
		auto Atomic<ValueType, UseLogger>::lock(auto&& condition_function, auto timeout) &
		-> DeepBase_::template LockReturnType_<decltype(*this), decltype(timeout), Nothrow>
		requires DeepBase_::template LockConstraint_<decltype(condition_function), decltype(timeout)>
		{return lock_<Nothrow>(*this, condition_function, timeout);}
}
