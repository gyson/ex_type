defmodule ExType.ArgumentExpander do
  @moduledoc false

  alias ExType.{Assert, Type}

  @type type :: Type.t()

  @spec expand_union_types([type]) :: [[type]]

  # for example, if input is [t1 | t2, t3 | t4]
  # it would be expanded to [ [t1, t3], [t1, t4], [t2, t3], [t2, t4] ]

  def expand_union_types([]) do
    []
  end

  def expand_union_types([%Type.Union{types: inner_types} = union_type]) do
    Assert.no_nested_union_types!(union_type)

    Enum.map(inner_types, fn type -> [type] end)
  end

  def expand_union_types([non_union_type]) do
    [[non_union_type]]
  end

  def expand_union_types([%Type.Union{types: inner_types} = union_type | rest_types])
      when length(rest_types) > 0 do
    Assert.no_nested_union_types!(union_type)

    rest_types
    |> expand_union_types()
    |> Enum.flat_map(fn expanded_rest_types ->
      Enum.map(inner_types, fn inner_type ->
        [inner_type | expanded_rest_types]
      end)
    end)
  end

  def expand_union_types([non_union_type | rest_types]) when length(rest_types) > 0 do
    rest_types
    |> expand_union_types()
    |> Enum.map(fn result_type ->
      [non_union_type | result_type]
    end)
  end
end
