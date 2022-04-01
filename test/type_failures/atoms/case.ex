defmodule TypeFailures.Atoms.Case do
  @spec wrong_atom(integer() | :foo) :: :bar
  def wrong_atom(x) do
    case x do
      :foo -> :bar
      _ -> :baz
    end
  end
end
