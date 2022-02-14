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

  alias ExType.{
    Type,
    Typespec,
    Context,
    Helper
  }

  require ExType.Helper

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
      Helper.throw(
        message: "not match union type",
        context: context,
        meta:
          case pattern do
            {_, meta, _} -> meta
            _ -> []
          end
      )
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

  def unify_pattern(context, atom, %Type.Atom{literal: false}) when is_atom(atom) do
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

  def unify_pattern(context, {:<<>>, _, args}, %Type.BitString{}) do
    Enum.reduce(args, context, fn
      {:"::", _, [{var, _, ctx}, size]}, acc
      when is_atom(var) and is_atom(ctx) and is_integer(size) ->
        Context.update_scope(acc, var, %Type.Integer{})

      {:"::", _, [{var, _, ctx}, {:bits, _, bits_ctx}]}, acc
      when is_atom(var) and is_atom(ctx) and is_atom(bits_ctx) ->
        Context.update_scope(acc, var, %Type.BitString{})

      # e.g. <<1::4>>
      {:"::", _, [left, right]}, acc when is_integer(left) and is_integer(right) ->
        acc

      # binary literal <<"HYLL">>
      {:"::", _, [bin, {:binary, _, []}]}, acc when is_binary(bin) ->
        acc

      {:"::", _, [{var, _, ctx}, {:-, _, [{:integer, _, []}, {:size, _, [size]}]}]}, acc
      when is_atom(var) and is_atom(ctx) and is_integer(size) ->
        Context.update_scope(acc, var, %Type.Integer{})

      # e.g. <<1::4>>
      {:"::", _, [int, {:-, _, [{:integer, _, []}, {:size, _, [size]}]}]}, acc
      when is_integer(int) and is_integer(size) ->
        acc

      {:"::", _,
       [
         {var, _, ctx},
         {:-, _, [{:-, _, [{:integer, _, []}, {:unsigned, _, []}]}, {:size, [], _}]}
       ]},
      acc
      when is_atom(var) and is_atom(ctx) ->
        Context.update_scope(acc, var, %Type.Integer{})

      {:"::", _,
       [{var, _, ctx}, {:-, _, [{:integer, _, []}, {:size, _, [{size_var, _, size_ctx}]}]}]},
      acc
      when is_atom(var) and is_atom(ctx) and is_atom(size_var) and is_atom(size_ctx) ->
        # TODO: assert size_var has type integer
        Context.update_scope(acc, var, %Type.Integer{})

      {:"::", _,
       [{var, _, ctx}, {:-, _, [{:bitstring, _, []}, {:size, _, [{size_var, _, size_ctx}]}]}]},
      acc
      when is_atom(var) and is_atom(ctx) and is_atom(size_var) and is_atom(size_ctx) ->
        # TODO: assert size_var has type integer
        Context.update_scope(acc, var, %Type.BitString{})

      {:"::", _, [int, {:integer, _, []}]}, acc when is_integer(int) ->
        acc

      {:"::", _, [{var, _, ctx}, {:integer, _, []}]}, acc when is_atom(var) and is_atom(ctx) ->
        Context.update_scope(acc, var, %Type.Integer{})

      {:"::", _, [{var, _, ctx}, {:float, _, []}]}, acc when is_atom(var) and is_atom(ctx) ->
        Context.update_scope(acc, var, %Type.Float{})

      {:"::", _, [{var, _, ctx}, {:bitstring, _, []}]}, acc when is_atom(var) and is_atom(ctx) ->
        Context.update_scope(acc, var, %Type.BitString{})

      {:"::", _, [{var, _, ctx}, {:-, _, [{:bitstring, _, []}, {:size, _, [size]}]}]}, acc
      when is_atom(var) and is_atom(ctx) and is_integer(size) ->
        Context.update_scope(acc, var, %Type.BitString{})
    end)
  end

  def unify_pattern(
        context,
        {:%, _, [struct, {:%{}, _, args}]},
        %ExType.Type.Struct{
          struct: struct_alias,
          types: types
        }
      )
      when is_atom(struct) and is_atom(struct_alias) and is_list(args) do
    Enum.reduce(args, context, fn {key, value}, context when is_atom(key) ->
      unify_pattern(context, value, Map.fetch!(types, key))
    end)
  end

  def unify_pattern(context, pattern, type) do
    Helper.throw(
      message: "unsupported pattern: #{Macro.to_string(pattern)} #{inspect(type)}",
      context: context,
      meta:
        case pattern do
          {_, meta, _} -> meta
          _ -> []
        end
    )
  end

  @spec unify_guard(Context.t(), any()) :: Context.t()

  def unify_guard(context, {{:., _, [:erlang, :is_atom]}, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.Atom{literal: false})
  end

  def unify_guard(context, {:is_atom, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.Atom{literal: false})
  end

  def unify_guard(context, {{:., _, [:erlang, :is_binary]}, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.BitString{})
  end

  def unify_guard(context, {:is_binary, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.BitString{})
  end

  def unify_guard(context, {{:., _, [:erlang, :is_bitstring]}, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.BitString{})
  end

  def unify_guard(context, {:is_bitstring, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.BitString{})
  end

  def unify_guard(context, {{:., _, [:erlang, :is_integer]}, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.Integer{})
  end

  def unify_guard(context, {:is_integer, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.Integer{})
  end

  def unify_guard(context, {{:., _, [:erlang, :is_float]}, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.Float{})
  end

  def unify_guard(context, {:is_float, _, [{var, _, ctx}]})
      when is_atom(var) and is_atom(ctx) do
    Context.update_scope(context, var, %Type.Float{})
  end

  def unify_guard(context, {{:., _, [:erlang, op]}, _, [_, _]})
      when op in [:>, :<, :>=, :"=<", :"=:="] do
    context
  end

  def unify_guard(context, {op, _, [_, _]}) when op in [:>, :<, :>=, :<=] do
    context
  end

  # TODO: add more type check

  def unify_guard(context, {{:., _, [:erlang, :andalso]}, _, [left, right]}) do
    context
    |> unify_guard(left)
    |> unify_guard(right)
  end

  # expanded form ?
  def unify_guard(
        context,
        {:case, _, [left, [do: [{:->, _, [[false], false]}, {:->, _, [[true], right]}]]]}
      ) do
    context
    |> unify_guard(left)
    |> unify_guard(right)
  end

  # expand from ExType.Parser.expand_all
  def unify_guard(
        context,
        {:case, _,
         [
           left,
           [
             do: [
               {:->, _, [[false], false]},
               {:->, _, [[true], right]},
               {:->, _, [[{:other, _, _}], _]}
             ]
           ]
         ]}
      ) do
    context
    |> unify_guard(left)
    |> unify_guard(right)
  end

  def unify_guard(context, true) do
    context
  end

  def unify_guard(context, guard) do
    Helper.throw(
      message: "unsupport guard: #{Macro.to_string(guard)}",
      context: context,
      meta:
        case guard do
          {_, meta, _} when is_list(meta) -> meta
          _ -> []
        end
    )
  end
end
