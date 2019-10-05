defmodule ExType.Filter do
  @moduledoc false

  # Support mix type.only

  @table_name ExType.Filter.Table
  @key_name ExType.Filter.Key

  def register(filter) do
    :ets.new(@table_name, [:named_table, :set])
    :ets.insert_new(@table_name, {@key_name, filter})
  end

  def get() do
    case :ets.info(@table_name) do
      :undefined ->
        fn _ -> true end

      _ ->
        :ets.lookup_element(@table_name, @key_name, 2)
    end
  end

  def parse(name) do
    name
    |> Code.string_to_quoted!()
    |> :elixir_expand.expand(__ENV__)
    |> elem(0)
    |> case do
      # check single function with specified arity
      {{:., _, [:erlang, :/]}, _, [{{:., _, [module, method]}, _, []}, arity]} ->
        fn
          {^module, ^method, ^arity} -> true
          _ -> false
        end

      # check single function
      {{:., _, [module, method]}, _, _} ->
        fn
          {^module, ^method, _arity} -> true
          _ -> false
        end

      # check single module
      module when is_atom(module) ->
        fn
          {^module, _method, _arity} -> true
          _ -> false
        end
    end
  end
end
