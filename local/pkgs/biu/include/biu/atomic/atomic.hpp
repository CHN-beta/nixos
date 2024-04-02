# pragma once
# include <biu/logger.hpp>

namespace biu::detail_
{
	template <DecayedType ValueType> class AtomicBase<ValueType, true>
		: public Logger::ObjectMonitor<Atomic<ValueType, true>>, protected AtomicBase<ValueType, false>
	{
		using DeepBase_ = AtomicBase<ValueType, false>;
		using DeepBase_::AtomicBase;
		public: class TimeoutException : public Logger::Exception<TimeoutException>
		{
			using Logger::Exception<TimeoutException>::Exception;
		};

		protected: template
		<
			bool ReturnFunctionResult,
			typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t, bool Nothrow = false
		> static auto apply_
		(
			auto&& atomic, auto&& function,
			ConditionFunction&& condition_function = nullptr, Duration timeout = nullptr
		) -> DeepBase_::template ApplyReturnType_
				<decltype(function), decltype(atomic), ReturnFunctionResult, ConditionFunction, Duration, Nothrow>
			requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(atomic), ConditionFunction, Duration>;

		protected: template <bool Nothrow = false, typename Duration = std::nullptr_t> static auto wait_
			(auto&& atomic, auto&& condition_function, Duration timeout = nullptr)
			-> DeepBase_::template WaitReturnType_<decltype(atomic), decltype(condition_function), Duration, Nothrow>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function), Duration>;

		protected: template
			<bool Nothrow = false, typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t>
			static auto lock_
			(auto&& atomic, ConditionFunction&& condition_function = nullptr, Duration timeout = nullptr)
			-> DeepBase_::template LockReturnType_<decltype(atomic), Duration, Nothrow>
			requires DeepBase_::template LockConstraint_<ConditionFunction, Duration>;
	};
}
