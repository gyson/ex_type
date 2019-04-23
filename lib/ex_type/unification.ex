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

  @spec unify_pattern(any(), Type.t(), Context.t()) :: {:ok, any(), Context.t()} | {:error, any()}

  def unify_pattern(integer, type, context) when is_integer(integer) do
    case type do
      %Type.Integer{} ->
        {:ok, type, context}
    end
  end

  def unify_pattern(float, type, context) when is_float(float) do
    case type do
      %Type.Float{} ->
        {:ok, type, context}
    end
  end

  def unify_pattern(binary, type, context) when is_binary(binary) do
    case type do
      %Type.BitString{} ->
        {:ok, type, context}
    end
  end

  def unify_pattern(atom, type, context) when is_atom(atom) do
    case type do
      %Type.Atom{literal: true, value: ^atom} ->
        {:ok, type, context}
    end
  end

  # {:ok, type, right}
  def unify_pattern({var, _, ctx}, type, context) when is_atom(var) and is_atom(ctx) do
    {:ok, type, Context.update_scope(context, var, type)}
  end

  # tuple
  def unify_pattern({first, second}, type, context) do
    unify_pattern({:{}, [], [first, second]}, type, context)
  end

  def unify_pattern({:{}, _, args} = pattern, type, context) do
    case type do
      %Type.TypedTuple{types: types} ->
        {unified_types, context} =
          Enum.zip(args, types)
          |> Enum.reduce({[], context}, fn {arg, t}, {acc, context} ->
            {:ok, type, context} = unify_pattern(arg, t, context)
            {acc ++ [type], context}
          end)

        {:ok, %Type.TypedTuple{types: unified_types}, context}

      %Type.Any{} ->
        new_context =
          Enum.reduce(args, context, fn arg, acc_context ->
            {:ok, _, acc_context} = unify_pattern(arg, %Type.Any{}, acc_context)
            acc_context
          end)

        {:ok, %Type.Any{}, new_context}

      _ ->
        Helper.pattern_error(pattern, type, context)
    end
  end

  # handle list
  def unify_pattern(list, type, context) when is_list(list) do
    case type do
      %Type.List{type: inner_type} ->
        case Enum.reverse(list) do
          [] ->
            {:ok, type, context}

          # if it's [a, b, c | d]
          [{:|, _, [left, right]} | items] ->
            new_context =
              [left | items]
              |> Enum.reverse()
              |> Enum.reduce(context, fn pattern, acc_context ->
                {:ok, _, new_acc} = unify_pattern(pattern, inner_type, acc_context)
                new_acc
              end)

            {:ok, _, new_context} = unify_pattern(right, type, new_context)

            {:ok, type, new_context}

          # [a, b, c] = [1, 2, 3]
          _ ->
            new_context =
              Enum.reduce(list, context, fn pattern, acc_context ->
                {:ok, _, new_acc} = unify_pattern(pattern, inner_type, acc_context)
                new_acc
              end)

            {:ok, type, new_context}
        end

      %Type.Any{} ->
        unify_pattern(list, %Type.List{type: %Type.Any{}}, context)
    end
  end

  def unify_pattern(pattern, type, context) do
    Helper.pattern_error(pattern, type, context)
  end

  @spec unify_guard(any(), Context.t()) :: {:ok, Context.t()} | {:error, any()}

  def unify_guard({{:., _, [:erlang, :is_atom]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.Atom{literal: false})}
  end

  def unify_guard({{:., _, [:erlang, :is_binary]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.BitString{kind: :binary})}
  end

  def unify_guard({{:., _, [:erlang, :is_bitstring]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.BitString{kind: :bitstring})}
  end

  def unify_guard({{:., _, [:erlang, :is_integer]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.Integer{})}
  end

  def unify_guard({{:., _, [:erlang, :is_float]}, _, [{var, _, ctx}]}, context)
      when is_atom(var) and is_atom(ctx) do
    {:ok, Context.update_scope(context, var, %Type.Float{})}
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
