defmodule ExType.Typespec.Elixir.EnumTestCase do
  require T

  # prevent some Elixir compiler warning
  defp noop(_), do: nil

  @spec test() :: any()

  def test() do
    x = [1, 2, 3]
    y = [1.1, 2.2, 3.3]
    z = [4, 5, 6]
    noop(x)
    noop(y)
    noop(z)

    T.assert(Enum.at(x, 1) == (integer() | nil))
    T.assert(Enum.at(x, 1, 0) == integer())

    T.assert(Enum.zip(x, y) == [{integer(), float()}])

    T.assert(Enum.concat([x, z]) == [integer()])

    # TODO: test Enum.flat_map_reduce
    # TODO: test Enum.into
  end
end
