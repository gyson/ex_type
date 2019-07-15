defmodule ExType.Example.Foo.StructExample do
  @moduledoc false

  @type t() :: %__MODULE__{
          hi: binary(),
          ok: integer()
        }
  defstruct [:hi, :ok]
end

defmodule ExType.Example.Foo do
  @moduledoc false

  require T

  @spec unquote_example() :: integer()

  hi = 12

  def unquote_example() do
    x = 10
    unquote(hi) + x
  end

  @okk 333

  @spec attribute_example() :: integer()

  def attribute_example() do
    @okk + 33
  end

  @spec inspect() :: any()

  def inspect() do
    T.inspect({1, 2})
  end

  @spec assert() :: any()

  def assert() do
    T.assert(10 == integer())
  end

  @spec hello() :: integer()

  def hello() do
    %{1 => 2, 3 => 4}
    |> Enum.map(fn {a, b} ->
      a + b
    end)
    |> Enum.flat_map(fn k ->
      [k, k]
    end)
    |> Enum.reduce(1, fn x, y ->
      x + y
    end)
  end

  @spec for_fn() :: [integer()]

  def for_fn() do
    for x <- [1, 2, 3] do
      x + 1
    end
  end

  @spec with_fn() :: integer()

  def with_fn() do
    with {:ok, a} <- {:ok, 123} do
      a + 1
    end
  end

  @spec call_defp(integer()) :: float()

  def call_defp(x) do
    add(x, 2.2)
  end

  defp add(a, b) do
    a + b
  end

  @spec fab(integer()) :: integer()

  def fab(0), do: 0
  def fab(1), do: 1
  def fab(n), do: fab(n - 1) + fab(n - 2)

  @spec hint() :: integer()

  def hint() do
    x = :erlang.binary_to_term("xxxxx")

    T.assert(x == any())

    T.assert(x :: integer())

    T.assert(x == integer())

    x
  end

  @hi 123

  @spec module_attribute() :: integer()

  def module_attribute() do
    @hi
  end

  @spec receive_example() :: any()

  def receive_example() do
    receive do
      {x} ->
        x

      [x] ->
        x
    end
  end

  @spec case_example(integer()) :: integer()

  def case_example(x) do
    case x do
      i -> i
    end
  end

  @spec cond_example(integer(), integer()) :: integer()

  def cond_example(a, b) do
    cond do
      a > b -> a
      true -> b
    end
  end

  @spec type_guard_case(any(), any(), any()) :: {integer(), float(), atom()}

  def type_guard_case(x, y, z) do
    case {x, y, z} do
      {a, b, c} when is_integer(a) and is_float(b) and is_atom(c) ->
        {a, b, c}
    end
  end

  @spec type_guard_receive() :: {integer(), float(), atom()}

  def type_guard_receive() do
    receive do
      {x, y, z} when is_integer(x) and is_float(y) and is_atom(z) ->
        {x, y, z}
    end
  end

  @spec struct() :: ExType.Example.Foo.StructExample.t()

  def struct() do
    %ExType.Example.Foo.StructExample{
      hi: "yes",
      ok: 123
    }
  end

  @spec destruct(ExType.Example.Foo.StructExample.t()) :: {binary(), integer()}

  def destruct(%ExType.Example.Foo.StructExample{hi: hi, ok: ok} = _f) do
    T.inspect({hi, ok})
  end

  @spec none_example() :: none()

  def none_example() do
    raise ArgumentError, "test"
  end

  @spec union_example({:ok, binary()} | :error) :: binary()

  def union_example({:ok, x}) do
    x
  end

  @spec binary_example(binary()) :: {integer(), integer(), bitstring()}

  def binary_example(<<a::1, b::1, c::bits>>) do
    {a, b, c}
  end

  @spec range_example() :: [float()]

  def range_example() do
    for i <- 1..10 do
      i + 2.0
    end
  end

  @spec map_to_list() :: [{binary(), integer()}]

  def map_to_list() do
    %{"hello" => 123}
    |> Map.to_list()
  end

  @spec map_values() :: [integer()]

  def map_values() do
    %{"hello" => 123}
    |> Map.values()
  end
end
