defmodule ExType.Checker.EvalError do
  @moduledoc false

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
    {:ok, %Type.BitString{}, context}
  end

  def eval(block, context) when is_binary(block) do
    {:ok, %Type.BitString{}, context}
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
      |> Enum.flat_map(fn
        # handle [1, 2, 3 | [4]]
        {:|, _, [left, right]} ->
          {:ok, left_val, _} = eval(left, context)

          case eval(right, context) do
            {:ok, %Type.List{type: right_val}, _} ->
              [left_val, right_val]
          end

        x ->
          {:ok, val, _} = eval(x, context)
          [val]
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
        new_context = Unification.unify_pattern(context, left, type_right)
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

          {:error, :not_found} ->
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
                {:error, type_error}
            end

          {:error, error} ->
            {:error, error}
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

    exprs
    |> Enum.reduce_while({:ok, default_nil, context}, fn
      expr, {:ok, _, acc_context} ->
        {:cont, eval(expr, acc_context)}

      _, {:error, error} ->
        {:halt, {:error, error}}
    end)
    |> case do
      {:ok, value, _} ->
        # block has its own scope
        {:ok, value, context}

      {:error, error} ->
        {:error, error}
    end
  end

  def eval({:=, _, [left, right]}, context) do
    {:ok, type, new_context} = eval(right, context)
    {:ok, type, Unification.unify_pattern(new_context, left, type)}
  end

  # unify pattern and spec

  # TODO: improve it for union types
  def eval({:case, _, [exp, [do: block]]}, context) do
    {:ok, type, context} = eval(exp, context)

    try do
      unioned_type =
        Enum.reduce(block, {type, []}, fn {:->, _, [[left], right]}, {acc_type, results} ->
          new_context =
            case left do
              {:when, _, [when_left, when_right]} ->
                context
                |> Unification.unify_pattern(when_left, acc_type)
                |> Unification.unify_guard(when_right)

              _ ->
                Unification.unify_pattern(context, left, acc_type)
            end

          case eval(right, new_context) do
            {:ok, result_type, _} ->
              {acc_type, [result_type | results]}

            {:error, error} ->
              throw(error)
          end
        end)
        |> elem(1)
        |> Typespec.union_types()

      {:ok, unioned_type, context}
    catch
      error -> {:error, error}
    end
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

        new_context = Unification.unify_pattern(context, left, generic_type)

        {:ok, type, _} = eval(expr, new_context)

        {:ok, %Type.List{type: type}, context}
    end
  end

  def eval({:with, _, args}, context) do
    case args do
      [{:<-, _, [left, right]}, [do: expr]] ->
        {:ok, type, _} = eval(right, context)
        new_context = Unification.unify_pattern(context, left, type)
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
              new_context = Unification.unify_pattern(context, when_left, %Type.Any{})
              {:ok, new_context} = Unification.unify_guard(when_right, new_context)
              new_context

            _ ->
              Unification.unify_pattern(context, left, %Type.Any{})
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

      {:error, :not_found} ->
        case Map.fetch(context.functions, {name, arity}) do
          {:ok, {fn_call, fn_block, fn_env}} ->
            {fn_name, fn_args, _, fn_body} = Parser.expand(fn_call, fn_block, fn_env)
            fn_arity = length(fn_args)

            # detect recursive function without typespec
            has_recursive_call? =
              Enum.any?(context.stacks, fn {name, arity} ->
                fn_name == name and fn_arity == arity
              end)

            if has_recursive_call? do
              {:error, "recurisive call with #{fn_name}/#{fn_arity}"}
            else
              fn_context =
                context
                |> Context.replace_env(fn_env)
                |> Context.append_stack(fn_name, length(fn_args))

              fn_context =
                Enum.zip(fn_args, args_types)
                |> Enum.reduce(fn_context, fn {arg, type}, acc_context ->
                  Unification.unify_pattern(acc_context, arg, type)
                end)

              case eval(fn_body, fn_context) do
                {:ok, type, _} ->
                  {:ok, type, context}

                {:error, error} ->
                  {:error, error}
              end
            end

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

      {:error, error} ->
        {:error, error}
    end
  end

  def eval({{:., _, [left, right]}, _, []}, context) when is_atom(right) do
    case eval(left, context) do
      {:ok, %Type.StructLikeMap{types: types}, context} ->
        case Map.fetch(types, right) do
          {:ok, type} ->
            {:ok, type, context}

          :error ->
            {:error, "invalid field #{right}"}
        end
    end
  end

  def eval(code, context) do
    Helper.eval_error(code, context)
  end
end
