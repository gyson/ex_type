defmodule ExType.Example.Foo do
  require T

  @spec unquote_example() :: integer()

  hi = 12

   def unquote_example() do
    x = 10
    unquote(hi) + x
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
end
