defmodule ExType.CustomEnv do
  @moduledoc false

  use ExType.Helper

  defmodule BeforeCompile do
    @moduledoc false

    defmacro __before_compile__(env) do
      get_attribute = fn module, attribute ->
        case Module.get_attribute(module, attribute) do
          nil -> []
          other -> other
        end
      end

      defs = get_attribute.(env.module, :ex_type_def)
      defps = get_attribute.(env.module, :ex_type_defp)

      # Helper.inspect(%{defs: defs, defps: defps, specs: specs})

      filter = ExType.Filter.get()

      # check each defs should have spec.
      defs
      # support "mix type" with filter
      |> Enum.filter(fn {{name, _, args}, _} ->
        module = ExType.Helper.get_module(env.module)
        filter.({module, name, length(args)})
      end)
      # |> Helper.inspect
      |> Enum.map(fn {call, block} ->
        ExType.CustomEnv.process_defs(call, block, env, defps)
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

  def process_defs(call, block, caller_env, defps) do
    # save call and do block, and eval it
    {name, _meta, args} = call

    # make `:elixir_expand.expand` works as expected
    current_vars =
      args
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
      |> Map.put(:function, {name, length(args)})
      |> Map.put(:current_vars, current_vars)

    module = Helper.get_module(caller_env.module)

    # TODO: support multiple functions pattern match
    functions =
      defps
      |> Enum.map(fn {{fn_name, _, fn_args}, fn_body} ->
        fn_arity = length(fn_args)

        {{fn_name, fn_arity}, {fn_args, fn_body, caller_env}}
      end)
      |> Enum.into(%{})

    context = %Context{env: caller_env, functions: functions}

    body =
      block
      |> Macro.postwalk(fn
        # support T.inspect
        {:., m1, [{:__aliases__, m2, [:T]}, :inspect]} ->
          {:., m1, [{:__aliases__, m2, [:ExType, :T]}, :inspect]}

        # support T.assert
        {{:., m1, [{:__aliases__, m2, [:T]}, :assert]}, m3, [arg]} ->
          case arg do
            {operator, _, [left, right]} when operator in [:==, :::, :<, :>] ->
              {{:., m1, [{:__aliases__, m2, [:ExType, :T]}, :assert]}, m3,
               [operator, left, Macro.escape(right)]}
          end

        code ->
          code
      end)
      |> :elixir_expand.expand(caller_env)
      |> elem(0)

    raw_fn = %Type.RawFunction{args: args, body: body, context: context}

    {:ok, [{inputs, output, map}]} = Typespec.get_spec(module, name, length(args))

    fn_typespec = %Type.TypedFunction{
      inputs: inputs,
      output: output
    }

    path_name = "#{Macro.to_string(module)}.#{name}/#{length(args)}"

    case Typespec.match_typespec(fn_typespec, raw_fn, map) do
      {:ok, _type, _} ->
        IO.puts("#{Emoji.one_test_pass()}  #{path_name}")

      {:error, _error} ->
        IO.puts("#{Emoji.one_test_fail()}  #{path_name}")
    end
  end
end
