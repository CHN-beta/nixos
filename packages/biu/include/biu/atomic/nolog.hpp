# pragma once
#	include <mutex>
#	include <optional>
#	include <condition_variable>
#	include <cstddef>
#	include <experimental/memory>
#	include <biu/common.hpp>
#	include <biu/concepts.hpp>
#	include <biu/called_by.hpp>

namespace biu
{
	template <DecayedType ValueType, bool UseLogger = true> class Atomic;
	namespace detail_
	{
		template <DecayedType ValueType, bool UseLogger> class AtomicBase;
		template <DecayedType ValueType> class AtomicBase<ValueType, false>
		{
			protected: mutable std::recursive_mutex Mutex_;
			protected: mutable std::condition_variable_any ConditionVariable_;
			protected: ValueType Value_;

			AtomicBase() = default;
			AtomicBase(const ValueType& value);
			AtomicBase(ValueType&& value);

			public: class TimeoutException : public std::exception
			{
				protected: std::string Message_;
				public: explicit TimeoutException(std::string message);
				public: const char* what() const noexcept override;
			};

			// Apply a function to stored value.
			// Wait for some time (if provided) until condition funciton returns true (if provided)
			// before applying the function.
			protected: template
				<
					typename Function, typename Atomic,
					typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t
				>
				constexpr static bool ApplyConstraint_ =
				(
					(std::invocable<Function, MoveQualifiers<Atomic, ValueType>> && std::is_null_pointer_v<ConditionFunction>)
          || (
						InvocableWithResult<ConditionFunction, bool, const ValueType&>
							&& (std::is_null_pointer_v<Duration> || SpecializationOf<Duration, std::chrono::duration>)
					)
				);
			protected: template
				<
					typename Function, typename Atomic, bool ReturnFunctionResult,
					typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t,
					bool Nothrow = false
				> using ApplyReturnType_ = std::conditional_t
					<
						Nothrow,
						std::conditional_t
						<
							ReturnFunctionResult && !std::is_void_v<std::invoke_result<Function, ValueType>>,
							std::optional<std::remove_cvref_t<FallbackIfNoTypeDeclared<std::invoke_result
								<Function, MoveQualifiers<Atomic, ValueType>, int>>>>,
							bool
						>,
						std::conditional_t
						<
							ReturnFunctionResult,
							std::invoke_result_t<Function, MoveQualifiers<Atomic, ValueType>>,
							Atomic&&
						>
					>;
			protected: template
				<
					bool ReturnFunctionResult,
					typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t,
					bool Nothrow = false
				> static auto apply_
				(
					auto&& atomic, auto&& function,
					ConditionFunction&& condition_function = nullptr, Duration timeout = nullptr
				) -> ApplyReturnType_
					<decltype(function), decltype(atomic), ReturnFunctionResult, ConditionFunction, Duration, Nothrow>
					requires ApplyConstraint_<decltype(function), decltype(atomic), ConditionFunction, Duration>;

			// Wait until condition funciton returns true, with an optional timeout
			protected: template <typename ConditionFunction, typename Duration = std::nullptr_t>
				constexpr static bool WaitConstraint_
				= (InvocableWithResult<ConditionFunction, bool, const ValueType&>
					&& (std::is_null_pointer_v<Duration> || SpecializationOf<Duration, std::chrono::duration>));
			protected: template
				<typename Atomic, typename ConditionFunction, typename Duration = std::nullptr_t, bool Nothrow = false>
				using WaitReturnType_
				= std::conditional_t<Nothrow && !std::is_null_pointer_v<Duration>, bool, Atomic&&>;
			protected: template <bool Nothrow = false, typename Duration = std::nullptr_t> static auto wait_
				(auto&& atomic, auto&& condition_function, Duration timeout = nullptr)
				-> WaitReturnType_<decltype(atomic), decltype(condition_function), Duration, Nothrow>
				requires WaitConstraint_<decltype(condition_function), Duration>;

			protected: template <typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t>
				constexpr static bool LockConstraint_
				= std::is_null_pointer_v<ConditionFunction> ||
					(
						InvocableWithResult<ConditionFunction, bool, const ValueType&>
							&& (std::is_null_pointer_v<Duration> || SpecializationOf<Duration, std::chrono::duration>)
					);
			protected: template <typename Atomic, typename Duration = std::nullptr_t, bool Nothrow = false>
				using LockReturnType_
				= std::conditional_t
					<
						Nothrow && !std::is_null_pointer_v<Duration>,
						std::optional<std::conditional_t
						<
							std::is_const_v<Atomic>,
							typename std::remove_reference_t<Atomic>::template Guard<true>,
							typename std::remove_reference_t<Atomic>::template Guard<false>
						>>,
						std::conditional_t
						<
							std::is_const_v<Atomic>,
							typename std::remove_reference_t<Atomic>::template Guard<true>,
							typename std::remove_reference_t<Atomic>::template Guard<false>
						>
					>;
			protected: template
				<bool Nothrow = false, typename ConditionFunction = std::nullptr_t, typename Duration = std::nullptr_t>
				static auto lock_
				(auto&& atomic, ConditionFunction&& condition_function = nullptr, Duration timeout = nullptr)
				-> LockReturnType_<decltype(atomic), Duration, Nothrow>
				requires LockConstraint_<ConditionFunction, Duration>;
		};
	}

	// Thread safe wrapper of custom class
	template <DecayedType ValueType, bool UseLogger> class Atomic : public detail_::AtomicBase<ValueType, UseLogger>
	{
		public: Atomic() = default;
		public: Atomic(const ValueType& value);
		public: Atomic(ValueType&& value);
		public: template <bool OtherUseLogger> Atomic(const Atomic<ValueType, OtherUseLogger>& other);
		public: template <bool OtherUseLogger> Atomic(Atomic<ValueType, OtherUseLogger>&& other);
		public: Atomic<ValueType, UseLogger>& operator=(const ValueType& value);
		public: Atomic<ValueType, UseLogger>& operator=(ValueType&& value);
		public: template <bool OtherUseLogger>
			Atomic<ValueType, UseLogger>& operator=(const Atomic<ValueType, OtherUseLogger>& other);
		public: template <bool OtherUseLogger>
			Atomic<ValueType, UseLogger>& operator=(Atomic<ValueType, OtherUseLogger>&& other);
		public: ValueType get() const&;
		public: ValueType get() &&;
		public: operator ValueType() const&;
		public: operator ValueType() &&;

		protected: using DeepBase_ = detail_::AtomicBase<ValueType, false>;

		public: template <bool ReturnFunctionResult = false> auto apply(auto&& function) const&
			-> DeepBase_::template ApplyReturnType_<decltype(function), decltype(*this), ReturnFunctionResult>
			requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this)>;
		public: template <bool ReturnFunctionResult = false> auto apply(auto&& function) &
			-> DeepBase_::template ApplyReturnType_<decltype(function), decltype(*this), ReturnFunctionResult>
			requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this)>;
		public: template <bool ReturnFunctionResult = false> auto apply(auto&& function) &&
			-> DeepBase_::template ApplyReturnType_<decltype(function), decltype(*this), ReturnFunctionResult>
			requires DeepBase_::template ApplyConstraint_<decltype(function), decltype(*this)>;
		public: template <bool ReturnFunctionResult = false>
			auto apply(auto&& function, auto&& condition_function) const&
			-> DeepBase_::template ApplyReturnType_
				<decltype(function), decltype(*this), ReturnFunctionResult, decltype(condition_function)>
			requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(*this), decltype(condition_function)>;
		public: template <bool ReturnFunctionResult = false> auto apply(auto&& function, auto&& condition_function) &
			-> DeepBase_::template ApplyReturnType_
				<decltype(function), decltype(*this), ReturnFunctionResult, decltype(condition_function)>
			requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(*this), decltype(condition_function)>;
		public: template <bool ReturnFunctionResult = false> auto apply(auto&& function, auto&& condition_function) &&
			-> DeepBase_::template ApplyReturnType_
				<decltype(function), decltype(*this), ReturnFunctionResult, decltype(condition_function)>
			requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(*this), decltype(condition_function)>;
		public: template <bool ReturnFunctionResult = false, bool Nothrow = false>
			auto apply(auto&& function, auto&& condition_function, auto timeout) const&
			-> DeepBase_::template ApplyReturnType_
			<
				decltype(function), decltype(*this), ReturnFunctionResult,
				decltype(condition_function), decltype(timeout), Nothrow
			> requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(*this), decltype(condition_function), decltype(timeout)>;
		public: template <bool ReturnFunctionResult = false, bool Nothrow = false>
			auto apply(auto&& function, auto&& condition_function, auto timeout) &
			-> DeepBase_::template ApplyReturnType_
			<
				decltype(function), decltype(*this), ReturnFunctionResult,
				decltype(condition_function), decltype(timeout), Nothrow
			> requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(*this), decltype(condition_function), decltype(timeout)>;
		public: template <bool ReturnFunctionResult = false, bool Nothrow = false>
			auto apply(auto&& function, auto&& condition_function, auto timeout) &&
			-> DeepBase_::template ApplyReturnType_
			<
				decltype(function), decltype(*this), ReturnFunctionResult,
				decltype(condition_function), decltype(timeout), Nothrow
			> requires DeepBase_::template ApplyConstraint_
				<decltype(function), decltype(*this), decltype(condition_function), decltype(timeout)>;

		public: auto wait(auto&& condition_function) const&
			-> DeepBase_::template WaitReturnType_<decltype(*this), decltype(condition_function)>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function)>;
		public: auto wait(auto&& condition_function) &
			-> DeepBase_::template WaitReturnType_<decltype(*this), decltype(condition_function)>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function)>;
		public: auto wait(auto&& condition_function) &&
			-> DeepBase_::template WaitReturnType_<decltype(*this), decltype(condition_function)>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function)>;
		public: template <bool Nothrow = false> auto wait(auto&& condition_function, auto timeout) const&
			-> DeepBase_::template WaitReturnType_
				<decltype(*this), decltype(condition_function), decltype(timeout), Nothrow>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function), decltype(timeout)>;
		public: template <bool Nothrow = false> auto wait(auto&& condition_function, auto timeout) &
			-> DeepBase_::template WaitReturnType_
				<decltype(*this), decltype(condition_function), decltype(timeout), Nothrow>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function), decltype(timeout)>;
		public: template <bool Nothrow = false> auto wait(auto&& condition_function, auto timeout) &&
			-> DeepBase_::template WaitReturnType_
				<decltype(*this), decltype(condition_function), decltype(timeout), Nothrow>
			requires DeepBase_::template WaitConstraint_<decltype(condition_function), decltype(timeout)>;

		// Attain lock from outside when constructing, and release when destructing.
		// For non-const variant, When destructing, ConditionVariable_.notify_all() is called.
		public: template <bool Const> class Guard
		{
			protected: std::unique_lock<std::recursive_mutex> Lock_;
			protected: std::experimental::observer_ptr
				<std::conditional_t<Const, const Atomic<ValueType, UseLogger>, Atomic<ValueType, UseLogger>>> Value_;

			public: template <bool OtherConst> Guard(const Guard<OtherConst>& other) requires (Const || !OtherConst);
			public: Guard
				(decltype(Lock_)&& lock, decltype(Value_) value, CalledBy<detail_::AtomicBase<ValueType, UseLogger>>);
			public: ~Guard();

			public: std::conditional_t<Const, const ValueType&, ValueType&> operator*() const&;
			public: std::conditional_t<Const, const ValueType*, ValueType*> operator->() const&;
			public: std::conditional_t<Const, const ValueType&, ValueType&> value() const&;
			public: auto operator*() const&& = delete;
			public: auto operator->() const&& = delete;
			public: auto value() const&& = delete;
		};

		public: auto lock() const& -> DeepBase_::template LockReturnType_<decltype(*this)>
			requires DeepBase_::template LockConstraint_<>;
		public: auto lock() & -> DeepBase_::template LockReturnType_<decltype(*this)>
			requires DeepBase_::template LockConstraint_<>;
		public: auto lock() const&& = delete;
		public: auto lock(auto&& condition_function) const&
			-> DeepBase_::template LockReturnType_<decltype(*this), decltype(condition_function)>
			requires DeepBase_::template LockConstraint_<decltype(condition_function)>;
		public: auto lock(auto&& condition_function) &
			-> DeepBase_::template LockReturnType_<decltype(*this), decltype(condition_function)>
			requires DeepBase_::template LockConstraint_<decltype(condition_function)>;
		public: auto lock(auto&& condition_function) const&& = delete;
		public: template <bool Nothrow = false> auto lock(auto&& condition_function, auto timeout) const&
			-> DeepBase_::template LockReturnType_<decltype(*this), decltype(timeout), Nothrow>
			requires DeepBase_::template LockConstraint_<decltype(condition_function), decltype(timeout)>;
		public: template <bool Nothrow = false> auto lock(auto&& condition_function, auto timeout) &
			-> DeepBase_::template LockReturnType_<decltype(*this), decltype(timeout), Nothrow>
			requires DeepBase_::template LockConstraint_<decltype(condition_function), decltype(timeout)>;
		public: template <bool Nothrow = false> auto lock(auto&& condition_function, auto timeout) const&& = delete;
	};
}
