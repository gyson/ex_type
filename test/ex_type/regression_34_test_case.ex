defmodule Regression34TestCase do
  @spec foo(:hi) :: :ok

  def foo(_) do
    raise "Oh noez"
  rescue
    _ -> :ok
  end

  @spec bar(any()) :: [:foo]

  def bar(_) do
    Enum.map([:foo], fn x -> x end)
  end
end
