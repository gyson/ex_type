defmodule ExType.CustomEnv do
  @moduledoc false

  alias ExType.{
    Context,
    Type,
    Typespec,
    Helper,
    Emoji,
    Parser
  }

  require ExType.Helper

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
        {{:when, meta_when, [{name, meta, args}, guards]}, block} ->
          {{:when, meta_when, [{name, meta, args || []}, guards]}, block}

        {{name, meta, args}, block} ->
          {{name, meta, args || []}, block}
      end)
      |> Enum.map(fn
        {{:when, _, [{name, _meta, args}, _guards]} = call, block} ->
          {call, block, name, length(args)}

        {{name, _meta, args} = call, block} ->
          {call, block, name, length(args)}
      end)
      |> Enum.filter(fn {_, _, name, arity} ->
        filter.({module, name, arity})
      end)
      |> Enum.filter(fn {_, _, name, arity} ->
        case ExType.Typespec.from_beam_spec(module, name, arity) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)
      |> Enum.group_by(fn {_, _, name, arity} -> {name, arity} end, fn {call, block, _, _} ->
        {call, block}
      end)
      |> Enum.map(fn {{name, arity}, call_blocks} ->
        ExType.CustomEnv.process_defs(name, arity, call_blocks, env, defps)
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

    # Manually expand `alias __MODULE__`, see https://github.com/gyson/ex_type/issues/27
    block = block
      |> Macro.prewalk(fn
          {:alias, meta_alias, [{:__MODULE__, meta_module, nil}]} -> {:alias, meta_alias, [{:__aliases__, meta_module, tokens}]}
          token -> token
        end)

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

  def process_defs(name, arity, call_blocks, caller_env, defps) do
    module = Helper.get_module(caller_env.module)

    # TODO: support multiple functions pattern match
    functions =
      defps
      |> Enum.map(fn {fn_call, fn_body} ->
        {fn_name, fn_args, _} = Parser.expand_call(fn_call)

        {{fn_name, length(fn_args)}, {fn_call, fn_body, caller_env}}
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    context =
      %Context{
        env: caller_env,
        functions: functions
      }
      |> Context.append_stack(name, arity)

    raw_fn = %Type.RawFunction{
      arity: arity,
      context: context,
      meta: [
        # if there are multiple clauses, use first one for meta line info
        line:
          call_blocks
          |> Enum.map(fn {{_, [line: line], _}, _} -> line end)
          |> Enum.min()
      ],
      clauses:
        Enum.map(call_blocks, fn {call, block} ->
          {^name, args, guard, body} = Parser.expand(call, block, caller_env)
          {args, guard, body}
        end)
    }

    case Typespec.fetch_specs(module, name, arity) do
      {:ok, [{inputs, output, map}]} ->
        fn_typespec = %Type.TypedFunction{
          inputs: inputs,
          output: output
        }

        path_name = "#{Macro.to_string(module)}.#{name}/#{arity}"

        try do
          Typespec.match_typespec(map, fn_typespec, raw_fn)
          IO.puts("#{Emoji.one_test_pass()}  #{path_name}")
        catch
          error ->
            IO.puts("""
            #{Emoji.one_test_fail()}  #{path_name}
               |
               | #{error.message}
               |
               | at #{error.location}
            """)

            if ExType.Debug.enabled?() do
              IO.puts("   * debug at #{error.debug_location}")
              IO.puts("   * stacktrace:")

              Enum.each(error.stacktrace, fn info ->
                IO.puts("        #{info}")
              end)
            end
        end
    end
  end
end
