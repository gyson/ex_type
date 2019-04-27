defmodule ExType.Unification.PatternError do
  @moduledoc false

  defstruct [:pattern, :type, :context, :line]
end

defmodule ExType.Unification.GuardError do
  @moduledoc false

  defstruct [:guard, :context, :line]
end

defmodule ExType.Unification do
  @moduledoc false

  use ExType.Helper

  @spec unify_pattern(Context.t(), any(), Type.t()) :: Context.t()

  # {:ok, yyy} = {:ok, xxx} | :error
  # should be able to match yyy to xxx

  def unify_pattern(context, pattern, %Type.Union{types: types}) do
    scopes =
      Enum.flat_map(types, fn type ->
        try do
          [unify_pattern(context, pattern, type).scope]
        catch
          _ -> []
        end
      end)

    if Enum.empty?(scopes) do
      Helper.throw("not match union type")
    end

    final_scope =
      Enum.reduce(scopes, fn s1, s2 ->
        Map.merge(s1, s2, fn _, t1, t2 ->
          Typespec.union_types([t1, t2])
        end)
      end)

    %{context | scope: final_scope}
  end

  def unify_pattern(context, {:\\, _, [left, _right]}, type) do
    # TODO: need to handle right ?
    unify_pattern(context, left, type)
  end

  def unify_pattern(context, integer, %Type.Integer{}) when is_integer(integer) do
    context
  end

  def unify_pattern(context, float, %Type.Float{}) when is_float(float) do
    context
  end

  def unify_pattern(context, binary, %Type.BitString{}) when is_binary(binary) do
    context
  end

  def unify_pattern(context, atom, %Type.Atom{literal: true, value: atom}) when is_atom(atom) do
    context
  end

  def unify_pattern(context, atom, %Type.Any{}) when is_atom(atom) do
    context
  end

  # {:ok, type, right}
  def unify_pattern(context, {var, _, ctx}, type) when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, type)
  end

  # tuple
  def unify_pattern(context, {first, second}, type) do
    unify_pattern(context, {:{}, [], [first, second]}, type)
  end

  def unify_pattern(context, {:{}, _, args}, %Type.TypedTuple{types: types})
      when length(args) == length(types) do
    Enum.zip(args, types)
    |> Enum.reduce(context, fn {arg, type}, acc_context ->
      unify_pattern(acc_context, arg, type)
    end)
  end

  def unify_pattern(context, {:{}, _, args}, %Type.AnyTuple{}) do
    Enum.reduce(args, context, fn arg, acc_context ->
      unify_pattern(acc_context, arg, %Type.Any{})
    end)
  end

  def unify_pattern(context, {:{}, _, _} = pattern, %Type.Any{}) do
    unify_pattern(context, pattern, %Type.AnyTuple{})
  end

  def unify_pattern(context, list, %Type.List{type: inner_type} = type) when is_list(list) do
    case list do
      [] ->
        context

      [{:|, _, [left, right]}] ->
        context
        |> unify_pattern(left, inner_type)
        |> unify_pattern(right, type)

      [x | rest] ->
        context
        |> unify_pattern(x, inner_type)
        |> unify_pattern(rest, type)
    end
  end

  def unify_pattern(context, list, %Type.Any{}) when is_list(list) do
    unify_pattern(context, list, %Type.List{type: %Type.Any{}})
  end

  def unify_pattern(context, {:<<>>, _, []}, %Type.BitString{}) do
    context
  end

  def unify_pattern(context, {:=, _, [left, right]}, type) do
    context
    |> unify_pattern(right, type)
    |> unify_pattern(left, type)
  end

  def unify_pattern(context, {:^, _, [_]}, _type) do
    # TODO: fix this
    context
  end

  def unify_pattern(context, {:%{}, _, [{left, right}]}, %Type.Map{key: key, value: value}) do
    context
    |> unify_pattern(left, key)
    |> unify_pattern(right, value)
  end

  def unify_pattern(_context, _pattern, _type) do
    Helper.throw("unsupported pattern")
  end

  @spec unify_guard(any(), Context.t()) :: {:ok, Context.t()} | {:error, any()}

  def unify_guard({{:., _, [:erlang, :is_atom]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.Atom{literal: false})}
  end

  def unify_guard({{:., _, [:erlang, :is_binary]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.BitString{})}
  end

  def unify_guard({{:., _, [:erlang, :is_bitstring]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.BitString{})}
  end

  def unify_guard({{:., _, [:erlang, :is_integer]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.Integer{})}
  end

  def unify_guard({{:., _, [:erlang, :is_float]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.Float{})}
  end

  def unify_guard({{:., _, [:erlang, op]}, _, [_, _]}, context) when op in [:>, :<, :>=, :<=] do
    {:ok, context}
  end

  # TODO: add more type check

  def unify_guard({{:., _, [:erlang, :andalso]}, _, [left, right]}, context) do
    {:ok, context} = unify_guard(left, context)
    unify_guard(right, context)
  end

  def unify_guard(guard, context) do
    Helper.guard_error(guard, context)
  end
end
