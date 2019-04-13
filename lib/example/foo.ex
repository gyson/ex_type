defmodule ExType.Example.Foo do
  use T

  @spec unquote_example() :: integer()

  def unquote_example() do
    unquote(12345) + 67890
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

  @spec call_defp() :: float()

  def call_defp() do
    my_defp(123, 2.2)
  end

  defp my_defp(a, b) do
    a + b
  end
end
