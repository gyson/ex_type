defmodule ExType.StreamTestCase do
  use T

  @spec hi() :: any()

  def hi() do
    T.assert(1.0 == float())
  end
end
