defmodule TypeFailures.Atoms.NoArgument do
  @spec wrong_atom() :: :blub
  def wrong_atom() do
    :bla
  end
end
