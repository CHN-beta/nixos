# pragma once
# include <concepts>
# include <tuple>
# include <type_traits>
# include <complex>

namespace biu
{
	template <typename T> concept DecayedType = std::same_as<std::decay_t<T>, T>;

	namespace detail_::specialization_of_detail_
	{
		template <typename Tuple> struct DropFirstMemberOfTupleHelper;
		template <typename First, typename... Others> struct DropFirstMemberOfTupleHelper<std::tuple<First, Others...>>
			{using Type = std::tuple<Others...>;};
		template <typename ProvidedArgs, typename ActualArgs> consteval bool check_provided_args();
		template <typename Class, template <typename...> typename Template> struct SpecializationOfHelper
			{template <typename... ProvidedArgs> consteval static bool check_provided_args();};
		template <template <typename...> typename Template, typename... ActualArgs>
			struct SpecializationOfHelper<Template<ActualArgs...>, Template>
			{template <typename... ProvidedArgs> consteval static bool check_provided_args();};
	}
	template <typename Class, template <typename...> typename Template, typename... ProvidedArgs>
		concept SpecializationOf
		= detail_::specialization_of_detail_::SpecializationOfHelper<std::decay_t<Class>, Template>
			::template check_provided_args<ProvidedArgs...>();

	template <typename T> concept CompletedType = sizeof(T) == sizeof(T);

	template <typename From, typename To> concept ImplicitlyConvertibleTo = std::is_convertible<From, To>::value;
	template <typename To, typename From> concept ImplicitlyConvertibleFrom = std::is_convertible<From, To>::value;
	template <typename From, typename To> concept ExplicitlyConvertibleTo = std::is_constructible<To, From>::value;
	template <typename To, typename From> concept ExplicitlyConvertibleFrom = std::is_constructible<To, From>::value;
	template <typename From, typename To> concept ConvertibleTo
		= ImplicitlyConvertibleTo<From, To> || ExplicitlyConvertibleTo<From, To>;
	template <typename From, typename To> concept ConvertibleFrom = ConvertibleTo<From, To>;

	template <typename Function, auto... Args> concept ConstevalInvokable
		= requires() {typename std::type_identity_t<int[(Function()(Args...), 1)]>;};

	template <typename T> concept Enumerable = std::is_enum_v<T>;

	template <typename Function, typename Result, typename... Args> concept InvocableWithResult
		= std::is_invocable_r_v<Result, Function, Args...>;
	
	template <typename T> concept Arithmetic = std::is_arithmetic<T>::value || SpecializationOf<T, std::complex>;
}
