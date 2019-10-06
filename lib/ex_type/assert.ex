defmodule ExType.Assert do
  @moduledoc false

  alias ExType.Type

  @spec no_nested_union_types!(Type.Union.t()) :: :ok

  def no_nested_union_types!(%Type.Union{types: inner_types} = union_type) do
    Enum.each(inner_types, fn
      %Type.Union{} ->
        raise "found nested union type: #{inspect(union_type)}"

      _ ->
        :ok
    end)
  end

  defp type_struct?(type) do
    with %{__struct__: struct} <- type,
         ["ExType", "Type", _] <- Module.split(struct) do
      true
    else
      _ -> false
    end
  end

  @spec is_type_struct!(map()) :: :ok

  def is_type_struct!(type) do
    case type_struct?(type) do
      true -> :ok
      false -> raise "#{inspect(type)} is not ExType.Type.Xxx struct"
    end
  end

  @spec is_list_of_type_structs!([map()]) :: :ok

  def is_list_of_type_structs!(types) when is_list(types) do
    Enum.each(types, &is_type_struct!(&1))
  end
end
