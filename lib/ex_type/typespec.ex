defmodule ExType.Typespec do
  @moduledoc false

  use ExType.Helper

  defmacro deftypespec(name, do: block) do
    module_name =
      case name do
        {:__aliases__, _, tokens} ->
          Module.concat([ExType.Typespec.Elixir | tokens])

        erlang_module when is_atom(erlang_module) ->
          Module.concat([ExType.Typespec, erlang_module])
      end

    # scan to find all specs
    defs =
      Macro.postwalk(block, [], fn code, acc ->
        case code do
          {:@, _, [{:spec, _, [{:::, _, [{name, _, args}, _]}]}]} ->
            {code, [{name, length(args)} | acc]}

          {:@, _, [{:spec, _, [{:when, _, [{:::, _, [{name, _, args}, _]}, _]}]}]} ->
            {code, [{name, length(args)} | acc]}

          _ ->
            {code, acc}
        end
      end)
      |> elem(1)
      # handle @spec unquote(:"====")(...) :: ...
      |> Enum.map(fn
        {{:unquote, _, [name]}, arity} -> {name, arity}
        {name, arity} -> {name, arity}
      end)
      |> Enum.uniq()
      |> Enum.map(fn {name, arity} ->
        quote do
          @dialyzer {:nowarn_function, {unquote(name), unquote(arity)}}
          def unquote(name)(unquote_splicing(List.duplicate(:_, arity))), do: nil
        end
      end)

    quote do
      defmodule unquote(module_name) do
        unquote(block)
        unquote_splicing(defs)
      end
    end
  end

  def from_beam_type(module, name, arity) do
    overrided_module = String.to_atom("Elixir.ExType.Typespec.#{module}")

    case fetch_type(overrided_module, name, arity) do
      {:ok, left, type} ->
        {:ok, left, type}

      {:error, _} ->
        case fetch_type(module, name, arity) do
          {:ok, left, type} ->
            {:ok, left, type}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def fetch_type(module, name, arity) do
    case Code.Typespec.fetch_types(module) do
      {:ok, ts} ->
        result =
          ts
          |> Enum.map(fn {kind, type} when kind in [:type, :typep] ->
            Code.Typespec.type_to_quoted(type)
          end)
          |> Enum.find(fn
            {:::, _, [{^name, _, args}, _]} when is_list(args) ->
              arity == length(args)

            _ ->
              false
          end)

        case result do
          nil ->
            {:error, {:not_found_type, module, name, arity}}

          {:::, _, [left, right]} ->
            {:ok, left, right}
        end

      :error ->
        {:error, {:not_found_type, module}}
    end
  end

  # {args, result, vars}
  def from_beam_spec(module, name, arity) when is_atom(module) do
    overrided_module = String.to_atom("Elixir.ExType.Typespec.#{module}")

    case fetch_specs(overrided_module, name, arity) do
      {:ok, specs} ->
        {:ok, convert_specs(specs, name)}

      {:error, _} ->
        case fetch_specs(module, name, arity) do
          {:ok, specs} ->
            {:ok, convert_specs(specs, name)}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp convert_specs(specs, name) do
    Enum.map(specs, fn spec ->
      {^name, args, result, vars} = convert_beam_spec(spec)
      {args, result, vars}
    end)
  end

  def fetch_specs(module, name, arity) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        matched =
          Enum.filter(specs, fn x ->
            elem(x, 0) == {name, arity}
          end)

        case matched do
          [{{^name, ^arity}, erlang_abstract_formats}] ->
            result =
              erlang_abstract_formats
              |> Enum.map(fn eaf ->
                Code.Typespec.spec_to_quoted(name, eaf)
              end)

            {:ok, result}

          _ ->
            {:error, "cannot find beam spec for #{module}, #{name}, #{arity}"}
        end

      :error ->
        {:error, "cannot find beam spec for #{module}"}
    end
  end

  def convert_beam_spec(spec) do
    case spec do
      {:::, _, [{name, _, args}, result]} ->
        {name, args, result, []}

      {:when, _, [{:::, _, [{name, _, args}, result]}, vars]} ->
        {name, args, result, vars}
    end
  end

  def union_types(types) do
    types
    |> Enum.flat_map(fn
      %Type.Union{types: inner_types} ->
        inner_types

      other ->
        [other]
    end)
    |> Enum.uniq()
    |> case do
      [one] ->
        one

      multi ->
        if Enum.member?(multi, %Type.Any{}) do
          %Type.Any{}
        else
          %Type.Union{types: Enum.sort(multi)}
        end
    end
  end

  # TODO: T.&({any(), x}) => x
  # TODO: T.&({any(), x, y}) => T.&({x, y})
  def intersect_types(_types) do
    Helper.todo()
  end
end
