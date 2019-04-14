defmodule ExType.CustomEnv do
  @moduledoc false

  use ExType.Helper

  defmodule BeforeCompile do
    defmacro __before_compile__(env) do
      get_attribute = fn module, attribute ->
        case Module.get_attribute(module, attribute) do
          nil -> []
          other -> other
        end
      end

      # get all specs now
      specs = get_attribute.(env.module, :spec)
      defs = get_attribute.(env.module, :ex_type_def)
      defps = get_attribute.(env.module, :ex_type_defp)

      # Helper.inspect(%{defs: defs, defps: defps, specs: specs})

      # check each defs should have spec.
      defs
      # support mix type.only
      |> Enum.filter(fn {{name, _, args}, _} ->
        ["ExType", "Module" | rest] = Module.split(env.module)
        ExType.Filter.need_process?(env.file, Module.concat(rest), name, length(args))
      end)
      # |> Helper.inspect
      |> Enum.map(fn {call, block} ->
        ExType.CustomEnv.process_defs(call, block, env, specs, defps)
      end)

      quote(do: nil)
    end
  end

  defmacro def(call, expr) do
    escaped_call = :elixir_quote.escape(call, :default, true)
    escaped_expr = :elixir_quote.escape(expr, :default, true)

    quote do
      ExType.CustomEnv.save_def(
        unquote(__CALLER__.module),
        unquote(escaped_call),
        unquote(escaped_expr)
      )

      Kernel.def(unquote(call), unquote(expr))
    end
  end

  defmacro defp(call, expr) do
    escaped_call = :elixir_quote.escape(call, :default, true)
    escaped_expr = :elixir_quote.escape(expr, :default, true)

    quote do
      ExType.CustomEnv.save_defp(
        unquote(__CALLER__.module),
        unquote(escaped_call),
        unquote(escaped_expr)
      )

      Kernel.defp(unquote(call), unquote(expr))
    end
  end

  # create new module with name: ExType.Module.XXX
  defmacro defmodule(alias, do: block) do
    {:__aliases__, meta, tokens} = alias
    new_alias = {:__aliases__, meta, [:ExType, :Module | tokens]}

    quote do
      Kernel.defmodule unquote(new_alias) do
        @before_compile ExType.CustomEnv.BeforeCompile
        unquote(block)
      end
    end
  end

  def save_def(module, call, do: block) do
    Module.register_attribute(module, :ex_type_def, accumulate: true, persist: true)
    Module.put_attribute(module, :ex_type_def, {call, block})
  end

  def save_defp(module, call, do: block) do
    Module.register_attribute(module, :ex_type_defp, accumulate: true, persist: true)
    Module.put_attribute(module, :ex_type_defp, {call, block})
  end

  def process_defs(call, block, caller_env, specs, defps) do
    # save call and do block, and eval it
    {name, _meta, vars} = call

    # make `:elixir_expand.expand` works as expected
    current_vars =
      vars
      |> Macro.postwalk([], fn
        {name, meta, ctx} = it, acc when is_atom(name) and is_atom(ctx) ->
          {it, [{name, meta, ctx} | acc]}

        other, acc ->
          {other, acc}
      end)
      |> elem(1)
      |> Enum.map(fn {name, meta, ctx} ->
        {{name, :elixir_utils.var_context(meta, ctx)}, {0, :term}}
      end)
      |> Enum.into(%{})

    # update env
    caller_env =
      caller_env
      |> Map.put(:function, {name, length(vars)})
      |> Map.put(:current_vars, current_vars)

    {args, expected_result, _type_variables} =
      specs
      |> Enum.flat_map(fn {:spec, spec, _} ->
        case ExType.Typespec.convert_beam_spec(spec) do
          {^name, args, result, vars} ->
            [{args, result, vars}]

          _ ->
            []
        end
      end)
      |> Enum.at(0)

    # TODO: support multiple functions pattern match
    functions =
      defps
      |> Enum.map(fn {{fn_name, _, fn_args}, fn_body} ->
        fn_arity = length(fn_args)

        {{fn_name, fn_arity}, {fn_args, fn_body, caller_env}}
      end)
      |> Enum.into(%{})

    spec_map =
      specs
      |> Enum.map(fn {:spec, spec, _} ->
        ExType.Typespec.convert_beam_spec(spec)
      end)
      |> Enum.group_by(
        fn {name, args, _, _} -> {name, length(args)} end,
        fn {_, args, result, vars} -> {args, result, vars} end
      )

    context = %Context{env: caller_env, functions: functions, specs: spec_map}

    {types, context} =
      Enum.reduce(args, {[], context}, fn input, {acc, ctx} ->
        {:ok, type, ctx} = ExType.Unification.unify_spec(input, %ExType.Type.Any{}, ctx)
        {acc ++ [type], ctx}
      end)

    context =
      Enum.zip(vars, types)
      |> Enum.reduce(context, fn {var, type}, context ->
        {:ok, _, context} = ExType.Unification.unify_pattern(var, type, context)
        context
      end)

    final_result =
      block
      |> Macro.postwalk(fn
        # support T.inspect
        {:., m1, [{:__aliases__, m2, [:T]}, :inspect]} ->
          {:., m1, [{:__aliases__, m2, [:ExType, :T]}, :inspect]}

        # support T.assert
        {{:., m1, [{:__aliases__, m2, [:T]}, :assert]}, m3, [arg]} ->
          {{:., m1, [{:__aliases__, m2, [:ExType, :T]}, :assert]}, m3, [Macro.escape(arg)]}

        code ->
          code
      end)
      |> :elixir_expand.expand(caller_env)
      |> elem(0)
      # |> Helper.inspect()
      |> ExType.Checker.eval(context)
      |> case do
        {:ok, result, _new_context} ->
          result
      end

    # if it can match
    case ExType.Unification.unify_spec(expected_result, final_result, context) do
      {:ok, type, _} ->
        <<"Elixir.ExType.Module.", module_name::binary>> = Atom.to_string(caller_env.module)
        Helper.inspect({:match, "#{module_name}.#{name}/#{length(vars)}", type})

      {:error, _} ->
        Helper.inspect({:not_match, name, expected_result, final_result})
    end
  end
end
