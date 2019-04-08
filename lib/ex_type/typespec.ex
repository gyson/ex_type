defmodule ExType.Typespec do
  @moduledoc false

  # {args, result, vars}
  def from_beam_spec(module, name, arity) do
    {module, name, arity} = Map.get(mapping(), {module, name, arity}, {module, name, arity})

    case get_spec(module, name, arity) do
      {:ok, specs} ->
        specs

      :none ->
        {:ok, specs} = Code.Typespec.fetch_specs(module)

        matched =
          Enum.filter(specs, fn x ->
            elem(x, 0) == {name, arity}
          end)

        case matched do
          [{{^name, ^arity}, erlang_abstract_formats}] ->
            erlang_abstract_formats
            |> Enum.map(fn eaf ->
              Code.Typespec.spec_to_quoted(name, eaf)
            end)

          _ ->
            raise "cannot find beam spec for #{module}, #{name}, #{arity}"
        end
    end
    |> Enum.map(fn spec -> convert_beam_spec(spec, name) end)
  end

  def convert_beam_spec(spec, name) do
    case spec do
      {:::, _, [{^name, _, args}, result]} ->
        {args, result, []}

      {:when, _, [{:::, _, [{^name, _, args}, result]}, vars]} ->
        {args, result, vars}
    end
  end

  def get_spec(module, name, arity) do
    case typespec() do
      %{^module => quoted} ->
        specs =
          case quoted do
            {:__block__, [], specs} ->
              specs

            {:@, _, _} = spec ->
              [spec]
          end

        specs
        |> Enum.map(fn {:@, _, [{:spec, _, [spec]}]} ->
          spec
        end)
        |> Enum.filter(fn
          {:when, [], [{:::, [], [{^name, _, args} | _]} | _]} when length(args) == arity ->
            true

          {:::, [], [{^name, _, args} | _]} ->
            true

          _ ->
            false
        end)
        |> case do
          [] ->
            :none

          x when is_list(x) ->
            {:ok, x}
        end

      _ ->
        :none
    end
  end

  # override exist type specs
  def typespec() do
    %{
      Code =>
        quote do
          @spec eval_string(binary()) :: {any(), [any()]}
        end,
      Enum =>
        quote do
          @spec map([x], (x -> y)) :: [y] when x: any(), y: any()

          @spec filter([x], (x -> boolean())) :: [x] when x: any()

          @spec flat_map([x], (x -> [y])) :: [y] when x: any(), y: any()

          @spec reduce([x], y, (x, y -> y)) :: y when x: any(), y: any()

          @spec reduce_while([x], y, (x, y -> {:cont, y} | {:halt, y})) :: y
                when x: any(), y: any()

          @spec join([binary()], binary()) :: binary()
        end,
      Stream =>
        quote do
          @spec map(Enumerable.t(x), (x -> y)) :: Enumerable.t(y) when x: any(), y: any()

          @spec filter(Enumerable.t(x), (x -> boolean())) :: Enumerable.t(x) when x: any()

          @spec flat_map(Enumerable.t(x), (x -> Enumerable.t(y))) :: Enumerable.t(y)
                when x: any(), y: any()
        end,
      Path =>
        quote do
          @spec wildcard(Path.t()) :: [binary()]
          @spec wildcard(Path.t(), [{:match_dot, boolean()}]) :: [binary()]
        end
    }
  end

  @spec mapping() :: %{{atom, atom, integer} => {atom, atom, integer}}

  def mapping() do
    %{
      {:erlang, :+, 1} => {Kernel, :+, 1},
      {:erlang, :+, 2} => {Kernel, :+, 2},
      {:erlang, :-, 1} => {Kernel, :-, 1},
      {:erlang, :-, 2} => {Kernel, :-, 2},
      {:erlang, :*, 2} => {Kernel, :*, 2},
      {:erlang, :/, 2} => {Kernel, :/, 2},
      {:erlang, :"/=", 2} => {Kernel, :!=, 2},
      {:erlang, :"=/=", 2} => {Kernel, :!==, 2},
      {:erlang, :<, 2} => {Kernel, :<, 2},
      {:erlang, :<=, 2} => {Kernel, :<=, 2},
      {:erlang, :==, 2} => {Kernel, :==, 2}
    }
  end
end
