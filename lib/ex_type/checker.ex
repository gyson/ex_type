defmodule ExType.Checker.EvalError do
  @moduledoc false

  defstruct [:code, :context, :line]
end

defmodule ExType.Checker do
  @moduledoc false

  use ExType.Helper

  @spec eval(Context.t(), any()) :: {Context.t(), Type.t()}

  def eval(context, {:%{}, _, []}) do
    {context, %Type.Map{key: %Type.Any{}, value: %Type.Any{}}}
  end

  def eval(context, {:%{}, _, args}) when is_list(args) do
    case eval(context, args) do
      {_, %Type.List{type: %Type.TypedTuple{types: [left, right]}}} ->
        {context, %Type.Map{key: left, value: right}}
    end
  end

  # bitstring
  def eval(context, {:<<>>, _, _}) do
    # TODO: type check internal arguments
    # TODO: distinguish binary and bitstring
    {context, %Type.BitString{}}
  end

  def eval(context, block) when is_binary(block) do
    {context, %Type.BitString{}}
  end

  def eval(context, {:%, _, [struct, {:%{}, _, args}]}) do
    if not Helper.is_struct(struct) do
      Helper.throw("#{struct} is not struct")
    end

    types =
      args
      |> Enum.map(fn {key, value} ->
        {_, value_type} = eval(context, value)
        {key, value_type}
      end)
      |> Enum.into(%{})

    # TODO: check if all types match with typespec

    {context, %Type.Struct{struct: struct, types: types}}
  end

  # atom literal
  def eval(context, block) when is_atom(block) do
    {context, %Type.Atom{literal: true, value: block}}
  end

  def eval(context, block) when is_integer(block) do
    {context, %Type.Integer{}}
  end

  def eval(context, block) when is_float(block) do
    {context, %Type.Float{}}
  end

  def eval(context, []) do
    {context, %Type.List{type: %Type.Any{}}}
  end

  def eval(context, list) when is_list(list) do
    type =
      list
      |> Enum.flat_map(fn
        # handle [1, 2, 3 | [4]]
        {:|, _, [left, right]} ->
          {_, left_val} = eval(context, left)

          case eval(context, right) do
            {_, %Type.List{type: right_val}} ->
              [left_val, right_val]
          end

        x ->
          {_, val} = eval(context, x)
          [val]
      end)
      |> Typespec.union_types()

    {context, %Type.List{type: type}}
  end

  # tuple

  def eval(context, {first, second}) do
    eval(context, {:{}, [], [first, second]})
  end

  def eval(context, {:{}, _, args}) do
    types =
      Enum.map(args, fn arg ->
        {_, val} = eval(context, arg)
        val
      end)

    {context, %Type.TypedTuple{types: types}}
  end

  def eval(context, {{:., _, [name]}, _, args}) do
    args_values =
      Enum.map(args, fn arg ->
        {_, val} = eval(context, arg)
        val
      end)

    {_, f} = eval(context, name)

    %Type.RawFunction{args: args, context: context, body: body} = f

    Enum.zip(args, args_values)
    |> Enum.reduce(context, fn {{name, _, nil}, type}, acc_context ->
      Context.update_scope(acc_context, name, type)
    end)
    |> eval(body)
  end

  # support T.inspect
  def eval(context, {{:., meta, [ExType.T, :inspect]}, _, args}) do
    location = "#{context.env.file}:#{Keyword.get(meta, :line, "?")}"

    case args do
      [item] ->
        {_, type} = result = eval(context, item)
        type_string = type |> ExType.Typespecable.to_quote() |> Macro.to_string()
        IO.puts("#{Emoji.inspect()}  T.inspect #{type_string} at #{location}")
        result

      _ ->
        Helper.throw("T.inspect bad argument error")
    end
  end

  # support T.assert
  def eval(context, {{:., meta, [ExType.T, :assert]}, _, [operator, left, escaped_right]}) do
    {right_spec, []} = Code.eval_quoted(escaped_right)

    # TODO: maybe use map from the context ?
    type_right = Typespec.eval_type(right_spec, {Helper.get_module(context.env.module), %{}})

    case operator do
      :== ->
        {_, type_left} = eval(context, left)

        if type_left == type_right do
          eval(context, nil)
        else
          location = "#{context.env.file}:#{Keyword.get(meta, :line, "?")}"
          left_string = type_left |> ExType.Typespecable.to_quote() |> Macro.to_string()
          right_string = type_right |> ExType.Typespecable.to_quote() |> Macro.to_string()
          IO.puts("#{Emoji.error()}  T.assert #{left_string} != #{right_string} at #{location}")

          Helper.throw("T.assert failed")
        end

      ::: ->
        context
        |> Unification.unify_pattern(left, type_right)
        |> eval(nil)
    end
  end

  def eval(context, {{:., _, [Module, :get_attribute]}, _, [module, attribute, _line]}) do
    eval(context, Module.get_attribute(module, attribute))
  end

  # remote function call, e.g. :erlang.binary_to_term/1, Map.get/2
  def eval(context, {{:., _, [module, name]}, meta, args})
      when is_atom(module) and is_atom(name) do
    args_types =
      Enum.map(args, fn arg ->
        {_, type} = eval(context, arg)
        type
      end)

    case Typespec.eval_spec(module, name, args_types) do
      {:ok, output} ->
        {context, output}

      {:error, :not_found} ->
        cond do
          # handle exception without spec
          name == :exception and length(args) == 1 and Helper.is_exception(module) ->
            expr =
              quote(do: %unquote(module){message: ""})
              |> :elixir_expand.expand(__ENV__)
              |> elem(0)

            eval(context, expr)

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

            Helper.throw("#{Emoji.error()}  Type Error `#{type_error}` at #{location}")
        end

      {:error, error} ->
        Helper.throw(error)
    end
  end

  # function
  def eval(context, {:fn, _, [{:->, _, [args, body]}]}) do
    # lazy eval
    {context,
     %Type.RawFunction{
       args: args,
       body: body,
       context: context
     }}
  end

  # variable
  def eval(context, {var, _, ctx}) when is_atom(var) and is_atom(ctx) do
    {context, Map.fetch!(context.scope, var)}
  end

  def eval(context, {:__block__, _, exprs}) do
    default_nil = %Type.Atom{literal: true, value: nil}

    {_, type} =
      Enum.reduce(exprs, {context, default_nil}, fn expr, {acc_context, _} ->
        eval(acc_context, expr)
      end)

    # block has its own scope
    {context, type}
  end

  def eval(context, {:=, _, [left, right]}) do
    {context, type} = eval(context, right)
    context = Unification.unify_pattern(context, left, type)
    {context, type}
  end

  # unify pattern and spec

  # TODO: improve it for union types
  def eval(context, {:case, _, [exp, [do: block]]}) do
    {_, type} = eval(context, exp)

    # TODO: if exp is a variable, we need to update it's variable type within scope

    unioned_type =
      Enum.map_reduce(block, type, fn {:->, _, [[left], right]}, acc_type ->
        new_context =
          case left do
            {:when, _, [when_left, when_right]} ->
              context
              |> Unification.unify_pattern(when_left, acc_type)
              |> Unification.unify_guard(when_right)

            _ ->
              Unification.unify_pattern(context, left, acc_type)
          end

        {_, result_type} = eval(new_context, right)

        {result_type, acc_type}
      end)
      |> elem(0)
      |> Typespec.union_types()

    {context, unioned_type}
  end

  def eval(context, {:cond, _, [[do: block]]}) do
    t =
      for {:->, _, [[left], right]} <- block do
        {_, left_type} = eval(context, left)

        true_type = %Type.Atom{literal: true, value: true}
        false_type = %Type.Atom{literal: true, value: false}
        boolean_type = Typespec.union_types([true_type, false_type])

        # left should be a boolean type
        case left_type do
          ^true_type -> :ok
          ^false_type -> :ok
          ^boolean_type -> :ok
        end

        {_, right_type} = eval(context, right)
        right_type
      end
      |> Typespec.union_types()

    {context, t}
  end

  # for expression
  def eval(context, {:for, _, args}) do
    case args do
      [{:<-, _, [left, right]}, [do: expr]] ->
        {_, right_type} = eval(context, right)

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

        {_, type} =
          context
          |> Unification.unify_pattern(left, generic_type)
          |> eval(expr)

        {context, %Type.List{type: type}}
    end
  end

  def eval(context, {:with, _, args}) do
    case args do
      [{:<-, _, [left, right]}, [do: expr]] ->
        {_, type} = eval(context, right)

        context
        |> Unification.unify_pattern(left, type)
        |> eval(expr)
    end
  end

  # handle receive do ... end
  def eval(context, {:receive, _, [[do: args]]}) do
    t =
      for {:->, _, [[left], right]} <- args do
        new_context =
          case left do
            {:when, _, [when_left, when_right]} ->
              context
              |> Unification.unify_pattern(when_left, %Type.Any{})
              |> Unification.unify_guard(when_right)

            _ ->
              Unification.unify_pattern(context, left, %Type.Any{})
          end

        {_, type} = eval(new_context, right)
        type
      end
      |> Typespec.union_types()

    {context, t}
  end

  # function call, e.g. 1 + 1
  def eval(context, {name, meta, args}) when is_atom(name) and is_list(args) do
    arity = length(args)

    args_types =
      Enum.map(args, fn arg ->
        {_, type} = eval(context, arg)
        type
      end)

    module = Helper.get_module(context.env.module)

    case Typespec.eval_spec(module, name, args_types) do
      {:ok, output} ->
        {context, output}

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
              Helper.throw("recurisive call with #{fn_name}/#{fn_arity}")
            end

            fn_context =
              context
              |> Context.replace_env(fn_env)
              |> Context.append_stack(fn_name, length(fn_args))

            fn_context =
              Enum.zip(fn_args, args_types)
              |> Enum.reduce(fn_context, fn {arg, type}, acc_context ->
                Unification.unify_pattern(acc_context, arg, type)
              end)

            {_, result_type} = eval(fn_context, fn_body)

            {context, result_type}

          :error ->
            context.env.functions
            |> Enum.find(fn {_, list} ->
              Enum.any?(list, fn {n, a} -> n == name and a == arity end)
            end)
            |> case do
              {module, _} ->
                eval(
                  context,
                  {{:., meta, [module, name]}, meta, args}
                )

              nil ->
                Helper.throw("unknown code")
            end
        end

      {:error, error} ->
        Helper.throw(error)
    end
  end

  def eval(context, {{:., _, [left, right]}, _, []}) when is_atom(right) do
    case eval(context, left) do
      {_, %Type.StructLikeMap{types: types}} ->
        case Map.fetch(types, right) do
          {:ok, type} ->
            {context, type}

          :error ->
            Helper.throw("invalid field #{right}")
        end
    end
  end

  def eval(_context, _code) do
    Helper.throw("unsupported expr")
  end
end
