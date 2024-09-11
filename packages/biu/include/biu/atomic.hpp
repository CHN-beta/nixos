# pragma once
#	include <mutex>
#	include <condition_variable>
#	include <experimental/memory>
#	include <biu/common.hpp>
#	include <biu/concepts.hpp>
#	include <biu/called_by.hpp>

namespace biu
{
	template <DecayedType ValueType> class Atomic
	{
		protected: mutable std::mutex Mutex_;
		protected: mutable std::condition_variable ConditionVariable_;
		protected: ValueType Value_;

		public: template <bool Const> class Guard
		{
			protected: std::unique_lock<std::mutex> Lock_;
			protected: std::experimental::observer_ptr
				<std::conditional_t<Const, const Atomic<ValueType>, Atomic<ValueType>>> Value_;

			public: template <bool OtherConst> Guard(Guard<OtherConst>&& other) requires (Const || !OtherConst);
			public: Guard
				(decltype(Lock_)&& lock, decltype(Value_) value, CalledBy<Atomic<ValueType>>);
			public: ~Guard();

			public: std::conditional_t<Const, const ValueType&, ValueType&> operator*() const&;
			public: std::conditional_t<Const, const ValueType*, ValueType*> operator->() const&;
			public: std::conditional_t<Const, const ValueType&, ValueType&> value() const&;
		};

		public: Atomic() = default;
		public: Atomic(auto&& value);
		public: Atomic& operator=(auto&& value);

		public: ValueType get(this auto&& self);
		public: operator ValueType(this auto&& self);

		protected: template <bool Throw = false> auto lock_(this auto&& self, auto&& condition_function, auto timeout);

		// Apply a function to stored value.
		// Wait for some time (if provided) until condition funciton returns true (if provided)
		// before applying the function.
		// NoReturn: throw exception if timeout, ignore function result, and return *this, if true;
		//		return bool or std::optional wrapped result of function, if false.
		// 		Useful when chaining multiple apply() calls.
		public: template <bool NoReturn = false> decltype(auto) apply
			(this auto&& self, auto&& function, auto&& condition_function, auto&& timeout);
		public: template <bool NoReturn = false> decltype(auto) apply
			(this auto&& self, auto&& function, auto&& condition_function);
		public: template <bool NoReturn = false> decltype(auto) apply(this auto&& self, auto&& function);

		// Wait until condition funciton returns true or *this, with an optional timeout
		public: template <bool NoReturn = false> decltype(auto) wait
			(this auto&& self, auto&& condition_function, auto timeout);
		public: template <bool NoReturn = false> decltype(auto) wait
			(this auto&& self, auto&& condition_function);

		// Attain lock from outside when constructing, and release when destructing.
		// Throw: same effect as NoReturn.
		public: template <bool Throw = false> auto lock(this auto&& self, auto&& condition_function, auto timeout);
		public: template <bool Throw = false> auto lock(this auto&& self, auto&& condition_function);
		public: template <bool Throw = false> auto lock(this auto&& self);
	};
}
