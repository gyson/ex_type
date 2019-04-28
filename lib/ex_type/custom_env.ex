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

      module = ExType.Helper.get_module(env.module)

      (defs ++ defps)
      # support "mix type" with filter
      |> Enum.map(fn
        {{:when, _, [{name, meta, args}, _guards]}, block} ->
          {{name, meta, args}, block}

        other ->
          other
      end)
      |> Enum.filter(fn {{name, _, args}, _} ->
        filter.({module, name, length(args)})
      end)
      |> Enum.filter(fn {{name, _, args}, _} ->
        case ExType.Typespec.from_beam_spec(module, name, length(args)) do
          {:ok, _} -> true
          {:error, _} -> false
        end
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
    {name, args, _guard, body} = Parser.expand(call, block, caller_env)

    module = Helper.get_module(caller_env.module)

    # TODO: support multiple functions pattern match
    functions =
      defps
      |> Enum.map(fn {fn_call, fn_body} ->
        {fn_name, fn_args, _} = Parser.expand_call(fn_call)

        {{fn_name, length(fn_args)}, {fn_call, fn_body, caller_env}}
      end)
      |> Enum.into(%{})

    context =
      %Context{
        env: caller_env,
        functions: functions
      }
      |> Context.append_stack(name, length(args))

    raw_fn = %Type.RawFunction{args: args, body: body, context: context}

    case Typespec.fetch_specs(module, name, length(args)) do
      {:ok, [{inputs, output, map}]} ->
        fn_typespec = %Type.TypedFunction{
          inputs: inputs,
          output: output
        }

        path_name = "#{Macro.to_string(module)}.#{name}/#{length(args)}"

        try do
          Typespec.match_typespec(map, fn_typespec, raw_fn)
          IO.puts("#{Emoji.one_test_pass()}  #{path_name}")
        catch
          error ->
            IO.puts("#{Emoji.one_test_fail()}  #{path_name}")

            if ExType.Debug.enabled?() do
              IO.inspect(error, label: "   #{Emoji.error()}  ")
            end
        end
    end
  end
end
