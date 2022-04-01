defmodule TypeChecks.Parametric.Function do
  @spec fun(t) :: t when t: var
  def fun(t) do
    t
  end
end
