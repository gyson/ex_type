defmodule ExType.Typespec.Elixir.EnumerableTestCase do
  require T

  @spec hi() :: any()

  def hi() do
    T.assert(1 == integer())
  end
end
