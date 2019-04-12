defmodule ExType.Checker.EvalError do
  defstruct [:code, :context, :line]
end

defmodule ExType.Checker do
  @moduledoc false

  use ExType.Helper

  @spec eval(any(), Context.t()) :: {:ok, Type.t(), Context.t()} | {:error, any()}

  def eval({:%{}, _, []}, context) do
    {:ok, %Type.Map{key: %Type.Any{}, value: %Type.Any{}}, context}
  end

  def eval({:%{}, _, args}, context) when is_list(args) do
    case eval(args, context) do
      {:ok, %Type.List{type: %Type.Tuple{types: [left, right]}}, _} ->
        {:ok, %Type.Map{key: left, value: right}, context}
    end
  end

  # bitstring
  def eval({:<<>>, _, _}, context) do
    # TODO: type check internal arguments
    # TODO: distinguish binary and bitstring
    {:ok, %Type.BitString{kind: :bitstring}, context}
  end

  def eval(block, context) when is_binary(block) do
    {:ok, %Type.BitString{kind: :binary}, context}
  end

  # bitstring literal
  def eval(block, context) when is_bitstring(block) do
    {:ok, %Type.BitString{kind: :bitstring}, context}
  end

  def eval({:%, _, [struct, {:%{}, _, _args}]}, context) do
    {:ok, %Type.Struct{struct: struct}, context}
  end

  # binary literal
  def eval(block, context) when is_binary(block) do
    {:ok, %Type.BitString{kind: :binary}, context}
  end

  def eval({:<<>>, _, args}, context) do
    for {:::, _, [left, right]} <- args do
      {:ok, val, _} = eval(left, context)

      case {val, right} do
        {%Type.BitString{kind: :binary}, {:binary, [], []}} ->
          :ok
      end
    end

    {:ok, %Type.BitString{kind: :binary}, context}
  end

  # atom literal
  def eval(block, context) when is_atom(block) do
    {:ok, %Type.Atom{literal: true, value: block}, context}
  end

  def eval(block, context) when is_integer(block) do
    {:ok, %Type.Number{kind: :integer}, context}
  end

  def eval(block, context) when is_float(block) do
    {:ok, %Type.Number{kind: :float}, context}
  end

  def eval([], context) do
    {:ok, %Type.List{type: %Type.Any{}}, context}
  end

  def eval(list, context) when is_list(list) do
    type =
      list
      |> Enum.map(fn x ->
        {:ok, val, _} = eval(x, context)
        val
      end)
      |> union_types()

    {:ok, %Type.List{type: type}, context}
  end

  # tuple

  def eval({first, second}, context) do
    eval({:{}, [], [first, second]}, context)
  end

  def eval({:{}, _, args}, context) do
    types =
      Enum.map(args, fn arg ->
        {:ok, val, _} = eval(arg, context)
        val
      end)

    {:ok, %Type.Tuple{types: types}, context}
  end

  def eval({{:., _, [name]}, _, args}, context) do
    args_values =
      Enum.map(args, fn arg ->
        {:ok, val, _} = eval(arg, context)
        val
      end)

    {:ok, f, _} = eval(name, context)

    %Type.Function{args: args, context: context, body: body} = f

    new_context =
      Enum.zip(args, args_values)
      |> Enum.reduce(context, fn {{name, _, nil}, type}, acc_context ->
        Context.update_scope(acc_context, name, type)
      end)

    eval(body, new_context)
  end

  # support module attribute
  def eval({{:., _, [Module, :get_attribute]}, _, [module, attribute, _line]}, context) do
    eval(Module.get_attribute(module, attribute), context)
  end

  # remote call
  def eval({{:., _, [module, name]}, _, args} = code, context) do
    args_types =
      Enum.map(args, fn arg ->
        {:ok, arg_type, _} = eval(arg, context)
        arg_type
      end)

    unified_types =
      Typespec.from_beam_spec(module, name, length(args))
      |> Enum.flat_map(fn {inputs, output, _vars} ->
        result =
          Enum.zip(inputs, args_types)
          |> Enum.reduce_while(context, fn {input, arg_type}, acc_context ->
            case Unification.unify_spec(input, arg_type, acc_context) do
              {:ok, _type, new_context} ->
                {:cont, new_context}

              {:error, error} ->
                {:halt, {:error, error}}
            end
          end)

        case result do
          {:error, _error} ->
            []

          context ->
            {:ok, type, _} = Unification.unify_spec(output, %Type.Any{}, context)
            [type]
        end
      end)

    if Enum.empty?(unified_types) do
      Helper.eval_error(code, context)
    else
      {:ok, union_types(unified_types), context}
    end
  end

  # function
  def eval({:fn, _, [{:->, _, [args, body]}]}, context) do
    # lazy eval
    {:ok,
     %Type.Function{
       args: args,
       body: body,
       context: context
     }, context}
  end

  # variable
  def eval({var, _, ctx}, context) when is_atom(var) and is_atom(ctx) do
    {:ok, Map.fetch!(context.scope, var), context}
  end

  def eval({:__block__, _, exprs}, context) do
    default_nil = %Type.Atom{literal: true, value: nil}

    {:ok, value, _} =
      Enum.reduce(exprs, {:ok, default_nil, context}, fn expr, {:ok, _, acc_context} ->
        eval(expr, acc_context)
      end)

    # block has its own scope
    {:ok, value, context}
  end

  def eval({:=, _, [left, right]}, context) do
    {:ok, type, _} = eval(right, context)

    {:ok, result, new_context} = Unification.unify_pattern(left, type, context)

    {:ok, result, new_context}
  end

  # unify pattern and spec
  def eval({:case, _, [_exp, [do: block]]}, context) do
    x =
      for {:->, _, [[left], right]} <- block do
        {:ok, _value_left, _} = eval(left, context)
        {:ok, value_right, _} = eval(right, context)

        value_right
      end
      |> union_types()

    {:ok, x, context}
  end

  def eval({:cond, _, [[do: block]]}, context) do
    t =
      for {:->, _, [[left], right]} <- block do
        {:ok, value_left, _} = eval(left, context)
        {:ok, value_right, _} = eval(right, context)

        # left should be a boolean type or true or false
        case value_left do
          %Type.Atom{literal: true, value: true} -> :ok
          %Type.Atom{literal: true, value: false} -> :ok
          _ -> raise "invalid type"
        end

        value_right
      end
      |> union_types()

    {:ok, t, context}
  end

  @type f(x) :: T.p(Enumerable.tq(), x)

  # for expression
  def eval({:for, _, args}, context) do
    case args do
      [{:<-, _, [left, right]}, [do: expr]] ->
        with {:ok, type, _} <- eval(right, context),
             # need to get Enumerable out
             {:ok, _, type_variable: %{x: x_type}} <-
               Unification.unify_spec(
                 {{:., [], [T, :p]}, [],
                  [{{:., [], [Enumerable, :t]}, [], []}, {:x, [], Elixir}]},
                 type,
                 context
               ),
             {:ok, _, new_context} <- Unification.unify_pattern(left, x_type, context),
             {:ok, type, _} <- eval(expr, new_context) do
          {:ok, %Type.List{type: type}, context}
        else
          error -> error
        end
    end
  end

  def eval(code, context) do
    Helper.eval_error(code, context)
  end

  def union_types(types) do
    case Enum.uniq(types) do
      [one] ->
        one

      multi ->
        # if it's multi, need to exclude any type
        multi
        |> Enum.filter(fn
          %Type.Any{} -> false
          _ -> true
        end)
        |> case do
          [one] -> one
          xxx -> %Type.Union{types: xxx}
        end
    end
  end
end
