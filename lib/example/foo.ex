defmodule ExType.Example.Foo do
  use T

  @spec hello(integer(), integer()) :: integer()

  def hello(x, y) do
    [x, y, 10]
    |> Enum.map(fn x ->
      x + 1
    end)
    |> Enum.reduce(1, fn x, acc ->
      x + acc
    end)
  end
end
