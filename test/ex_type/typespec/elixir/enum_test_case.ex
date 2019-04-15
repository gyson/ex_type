defmodule ExType.Typespec.Elixir.EnumTestCase do
  require T

  # prevent some Elixir compiler warning
  defp noop(_), do: nil

  @spec test() :: any()

  def test() do
    x = [1, 2, 3]
    y = [1.1, 2.2, 3.3]
    noop(x)
    noop(y)

    T.assert(Enum.at(x, 1) == (integer() | nil))
    T.assert(Enum.at(x, 1, 0) == integer())

    # TODO: fix type variable naming conflict issue
    # T.assert(Enum.zip(x, y) == [{integer(), float()}])
  end
end
