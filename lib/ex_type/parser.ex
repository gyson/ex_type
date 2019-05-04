defmodule ExType.Parser do
  @moduledoc false

  def expand_call({:when, _, [{name, _, args}, guard]}) do
    {name, args, guard}
  end

  def expand_call({name, _, args}) do
    # `true` guard is the same as no guard
    {name, args, true}
  end

  # return {name, args, guard, block}
  def expand(call, block, env) do
    {name, args, guard} = expand_call(call)

    # find all bindings in args
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

    updated_env =
      env
      |> Map.put(:function, {name, length(args)})
      |> Map.put(:current_vars, current_vars)

    expanded_args =
      Enum.map(args, fn arg ->
        arg
        |> Macro.postwalk(fn
          # avoid underscore variable warning
          {name, meta, ctx} = code when is_atom(name) and is_atom(ctx) ->
            if String.at(Atom.to_string(name), 0) == "_" do
              {name, Keyword.put(meta, :generated, true), ctx}
            else
              code
            end

          code ->
            code
        end)
        |> :elixir_expand.expand(updated_env)
        |> elem(0)
      end)

    expanded_guard = guard |> :elixir_expand.expand(updated_env) |> elem(0)

    expanded_body =
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
      |> :elixir_expand.expand(updated_env)
      |> elem(0)

    {name, expanded_args, expanded_guard, expanded_body}
  end
end
