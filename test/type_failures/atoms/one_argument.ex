defmodule TypeFailures.Atoms.OneArgument do
  @spec wrong_atom(any()) :: :foo
  def wrong_atom(_) do
    :bar
  end
end
