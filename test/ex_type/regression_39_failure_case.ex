defmodule Regression39FailureCase do
  @type t(elem) :: [elem]

  @spec mylength(t(term())) :: integer()

  def mylength(:foo) do
    42
  end
end
