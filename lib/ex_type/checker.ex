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
      {:ok, %Type.List{type: %Type.TypedTuple{types: [left, right]}}, _} ->
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

  def eval({:%, _, [struct, {:%{}, _, args}]} = code, context) do
    if Helper.is_struct(struct) do
      types =
        args
        |> Enum.map(fn {key, value} ->
          {:ok, value_type, _} = eval(value, context)
          {key, value_type}
        end)
        |> Enum.into(%{})

      # TODO: check if all types match with typespec

      {:ok, %Type.Struct{struct: struct, types: types}, context}
    else
      Helper.eval_error(code, context)
    end
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
    {:ok, %Type.Integer{}, context}
  end

  def eval(block, context) when is_float(block) do
    {:ok, %Type.Float{}, context}
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
      |> Typespec.union_types()

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

    {:ok, %Type.TypedTuple{types: types}, context}
  end

  def eval({{:., _, [name]}, _, args}, context) do
    args_values =
      Enum.map(args, fn arg ->
        {:ok, val, _} = eval(arg, context)
        val
      end)

    {:ok, f, _} = eval(name, context)

    %Type.RawFunction{args: args, context: context, body: body} = f

    new_context =
      Enum.zip(args, args_values)
      |> Enum.reduce(context, fn {{name, _, nil}, type}, acc_context ->
        Context.update_scope(acc_context, name, type)
      end)

    eval(body, new_context)
  end

  # support T.inspect
  def eval({{:., meta, [ExType.T, :inspect]}, _, args} = code, context) do
    location = "#{context.env.file}:#{Keyword.get(meta, :line, "?")}"

    case args do
      [item] ->
        {:ok, type, _} = result = eval(item, context)
        type_string = type |> ExType.Typespecable.to_quote() |> Macro.to_string()
        IO.puts("#{Emoji.inspect()}  T.inspect #{type_string} at #{location}")
        result

      _ ->
        Helper.eval_error(code, context)
    end
  end

  # support T.assert
  def eval({{:., meta, [ExType.T, :assert]}, _, [operator, left, escaped_right]} = code, context) do
    {right_spec, []} = Code.eval_quoted(escaped_right)

    # TODO: maybe use map from the context ?
    type_right = Typespec.eval_type(right_spec, {Helper.get_module(context.env.module), %{}})

    case operator do
      :== ->
        {:ok, type_left, _} = eval(left, context)

        if type_left == type_right do
          eval(nil, context)
        else
          location = "#{context.env.file}:#{Keyword.get(meta, :line, "?")}"
          left_string = type_left |> ExType.Typespecable.to_quote() |> Macro.to_string()
          right_string = type_right |> ExType.Typespecable.to_quote() |> Macro.to_string()
          IO.puts("#{Emoji.error()}  T.assert #{left_string} != #{right_string} at #{location}")

          Helper.eval_error(code, context)
        end

      ::: ->
        {:ok, _, new_context} = Unification.unify_pattern(left, type_right, context)
        eval(nil, new_context)
    end
  end

  def eval({{:., _, [Module, :get_attribute]}, _, [module, attribute, _line]}, context) do
    eval(Module.get_attribute(module, attribute), context)
  end

  # remote function call, e.g. :erlang.binary_to_term/1, Map.get/2
  def eval({{:., _, [module, name]}, meta, args}, context)
      when is_atom(module) and is_atom(name) do
    Enum.reduce_while(args, [], fn arg, acc ->
      case eval(arg, context) do
        {:ok, arg_type, _} ->
          {:cont, acc ++ [arg_type]}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:error, error} ->
        {:error, error}

      args_types ->
        case Typespec.eval_spec(module, name, args_types) do
          {:ok, output} ->
            {:ok, output, context}

          {:error, error} ->
            cond do
              # handle exception without spec
              name == :exception and length(args) == 1 and Helper.is_exception(module) ->
                quote(do: %unquote(module){message: ""})
                |> :elixir_expand.expand(__ENV__)
                |> elem(0)
                |> eval(context)

              true ->
                location = "#{context.env.file}:#{Keyword.get(meta, :line, "?")}"

                type_error =
                  quote do
                    unquote(module).unquote(name)(
                      unquote_splicing(
                        Enum.map(args_types, fn type ->
                          Typespecable.to_quote(type)
                        end)
                      )
                    )
                  end
                  |> Macro.to_string()

                IO.puts("#{Emoji.error()}  Type Error `#{type_error}` at #{location}")
                {:error, error}
            end
        end
    end
  end

  # function
  def eval({:fn, _, [{:->, _, [args, body]}]}, context) do
    # lazy eval
    {:ok,
     %Type.RawFunction{
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
  def eval({:case, _, [exp, [do: block]]}, context) do
    {:ok, type, context} = eval(exp, context)

    unioned_type =
      for {:->, _, [[left], right]} <- block do
        new_context =
          case left do
            {:when, _, [when_left, when_right]} ->
              {:ok, _, new_context} = Unification.unify_pattern(when_left, type, context)
              {:ok, new_context} = Unification.unify_guard(when_right, new_context)
              new_context

            _ ->
              {:ok, _, new_context} = Unification.unify_pattern(left, type, context)
              new_context
          end

        {:ok, result_type, _} = eval(right, new_context)

        result_type
      end
      |> Typespec.union_types()

    {:ok, unioned_type, context}
  end

  def eval({:cond, _, [[do: block]]}, context) do
    t =
      for {:->, _, [[left], right]} <- block do
        {:ok, left_type, _} = eval(left, context)

        true_type = %Type.Atom{literal: true, value: true}
        false_type = %Type.Atom{literal: true, value: false}
        boolean_type = Typespec.union_types([true_type, false_type])

        # left should be a boolean type
        case left_type do
          ^true_type -> :ok
          ^false_type -> :ok
          ^boolean_type -> :ok
        end

        {:ok, right_type, _} = eval(right, context)
        right_type
      end
      |> Typespec.union_types()

    {:ok, t, context}
  end

  # for expression
  def eval({:for, _, args}, context) do
    case args do
      [{:<-, _, [left, right]}, [do: expr]] ->
        {:ok, right_type, _} = eval(right, context)

        generic = %Type.SpecVariable{
          name: :ex_type_for,
          type: %Type.Any{},
          spec: {nil, nil, 0},
          id: :erlang.unique_integer()
        }

        {:ok, _, map} =
          Typespec.match_typespec(
            %Type.GenericProtocol{module: Enumerable, generic: generic},
            right_type,
            %{}
          )

        generic_type = Map.fetch!(map, generic)

        {:ok, _, new_context} = Unification.unify_pattern(left, generic_type, context)

        {:ok, type, _} = eval(expr, new_context)

        {:ok, %Type.List{type: type}, context}
    end
  end

  def eval({:with, _, args}, context) do
    case args do
      [{:<-, _, [left, right]}, [do: expr]] ->
        {:ok, type, _} = eval(right, context)
        {:ok, _, new_context} = Unification.unify_pattern(left, type, context)
        eval(expr, new_context)
    end
  end

  # handle receive do ... end
  def eval({:receive, _, [[do: args]]}, context) do
    t =
      for {:->, _, [[left], right]} <- args do
        new_context =
          case left do
            {:when, _, [when_left, when_right]} ->
              {:ok, _, new_context} = Unification.unify_pattern(when_left, %Type.Any{}, context)
              {:ok, new_context} = Unification.unify_guard(when_right, new_context)
              new_context

            _ ->
              {:ok, _, new_context} = Unification.unify_pattern(left, %Type.Any{}, context)
              new_context
          end

        {:ok, type, _} = eval(right, new_context)
        type
      end
      |> Typespec.union_types()

    {:ok, t, context}
  end

  # function call, e.g. 1 + 1
  def eval({name, meta, args} = code, context) when is_atom(name) and is_list(args) do
    arity = length(args)

    args_types =
      Enum.map(args, fn arg ->
        {:ok, type, _} = eval(arg, context)
        type
      end)

    module = Helper.get_module(context.env.module)

    case Typespec.eval_spec(module, name, args_types) do
      {:ok, output} ->
        {:ok, output, context}

      {:error, _} ->
        case Map.fetch(context.functions, {name, arity}) do
          {:ok, {fn_args, fn_body, fn_env}} ->
            fn_context = %Context{env: fn_env, functions: context.functions}

            fn_context =
              Enum.zip(fn_args, args_types)
              |> Enum.reduce(fn_context, fn {arg, type}, acc_context ->
                {:ok, _, acc_context} = Unification.unify_pattern(arg, type, acc_context)
                acc_context
              end)

            {:ok, type, _} = eval(fn_body, fn_context)

            {:ok, type, context}

          :error ->
            context.env.functions
            |> Enum.find(fn {_, list} ->
              Enum.any?(list, fn {n, a} -> n == name and a == arity end)
            end)
            |> case do
              {module, _} ->
                eval(
                  {{:., meta, [module, name]}, meta, args},
                  context
                )

              nil ->
                Helper.eval_error(code, context)
            end
        end
    end
  end

  def eval(code, context) do
    Helper.eval_error(code, context)
  end
end
