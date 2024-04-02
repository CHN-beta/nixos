# pragma once
# include <tuple>
# include <biu/concepts.hpp>

namespace biu
{
	template <typename ProvidedArgs, typename ActualArgs> consteval bool
		detail_::specialization_of_detail_::check_provided_args()
	{
		if constexpr (std::tuple_size_v<ProvidedArgs> == 0)
			return true;
		else if constexpr (std::tuple_size_v<ActualArgs> == 0)
			return false;
		else if constexpr
			(std::same_as<std::tuple_element_t<0, ProvidedArgs>, std::tuple_element_t<0, ActualArgs>>)
			return check_provided_args 
			<
				typename DropFirstMemberOfTupleHelper<ProvidedArgs>::Type,
				typename DropFirstMemberOfTupleHelper<ActualArgs>::Type
			>();
		else
			return false;
	}
	template <typename Class, template <typename...> typename Template> template <typename... ProvidedArgs> consteval
		bool detail_::specialization_of_detail_::SpecializationOfHelper<Class, Template>::check_provided_args()
		{ return false; }
	template <template <typename...> typename Template, typename... ActualArgs> template <typename... ProvidedArgs>
		consteval bool detail_::specialization_of_detail_::SpecializationOfHelper
			<Template<ActualArgs...>, Template>::check_provided_args()
		{
			return specialization_of_detail_::check_provided_args
				<std::tuple<ProvidedArgs...>, std::tuple<ActualArgs...>>();
		}
}
