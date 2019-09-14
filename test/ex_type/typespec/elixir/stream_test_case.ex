defmodule ExType.Typespec.Elixir.StreamTestCase do
  require ExType.T
  alias ExType.T

  @spec hi() :: any()

  def hi() do
    T.assert(1.0 == float())
  end
end
