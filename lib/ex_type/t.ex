defmodule ExType.T do
  @moduledoc false

  @spec inspect(x) :: x when x: any()

  def inspect(x) do
    x
  end

  @spec assert(any(), any(), any()) :: nil

  def assert(_, _, _) do
    nil
  end
end
