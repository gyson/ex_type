defmodule ExType.CheckerTestCase do
  require T

  @spec test_case_1({:ok, integer()} | :error) :: any()

  def test_case_1(input) do
    case input do
      {:ok, x} ->
        T.assert(x == integer())
        x

      error ->
        T.assert(error == :error)
        error
    end
  end

  @spec test_case_2(:ok | integer()) :: integer()

  def test_case_2(input) do
    case input do
      :ok ->
        123

      x when x > 10 ->
        T.assert(x == integer())
        x

      other ->
        T.assert(other == integer())
        other
    end
  end
end
