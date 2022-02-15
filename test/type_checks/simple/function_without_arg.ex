defmodule TypeChecks.Simple.FunctionWithoutArg do
  @spec fun() :: integer()
  def fun do
    23
  end
end
