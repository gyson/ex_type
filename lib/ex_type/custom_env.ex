defmodule ExType.CustomEnv do
  @moduledoc false

  use ExType.Helper

  defmodule BeforeCompile do
    defmacro __before_compile__(env) do
      # get all specs now
      specs = Module.get_attribute(env.module, :spec)
      defs = Module.get_attribute(env.module, :ex_type_def)
      defps = Module.get_attribute(env.module, :ex_type_defp)

      # Helper.inspect(%{defs: defs, defps: defps, specs: specs})

      # check each defs should have spec.
      defs
      # support mix type.only
      |> Enum.filter(fn {{name, _, args}, _, _} ->
        ["ExType", "Module" | rest] = Module.split(env.module)
        ExType.Filter.need_process?(env.file, Module.concat(rest), name, length(args))
      end)
      # |> Helper.inspect
      |> Enum.map(fn {call, block, env} ->
        ExType.CustomEnv.process_defs(call, block, env, specs, defps)
      end)

      quote(do: nil)
    end
  end

  defmacro def(call, do: block) do
    ExType.CustomEnv.save_def(__CALLER__.module, call, block, __CALLER__)

    quote do
      # @ex_type_def quote(do: {unquote(call), unquote(block), unquote(__CALLER__)})
      Kernel.def(unquote(call), do: unquote(block))
    end
  end

  defmacro defp(call, do: block) do
    ExType.CustomEnv.save_defp(__CALLER__.module, call, block, __CALLER__)

    quote do
      Kernel.defp(unquote(call), do: unquote(block))
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

  def save_def(module, call, block, caller_env) do
    Module.register_attribute(module, :ex_type_def, accumulate: true, persist: true)
    Module.put_attribute(module, :ex_type_def, {call, block, caller_env})
  end

  def save_defp(module, call, block, caller_env) do
    Module.register_attribute(module, :ex_type_defp, accumulate: true, persist: true)
    Module.put_attribute(module, :ex_type_defp, {call, block, caller_env})
  end

  def process_defs(call, block, caller_env, specs, _defps) do
    # save call and do block, and eval it
    {name, _meta, vars} = call

    exist_vars = Map.get(caller_env, :current_vars, %{})

    new_vars =
      vars
      |> Enum.reduce(exist_vars, fn {name, _, nil}, acc ->
        Map.put(acc, {name, nil}, {0, :term})
      end)

    env = Map.put(caller_env, :current_vars, new_vars)

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

    context = %Context{env: env}

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
      # Note: it's private API
      |> :elixir_expand.expand(env)
      |> elem(0)
      # |> Macro.to_string() |> IO.puts
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
