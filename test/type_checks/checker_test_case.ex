defmodule TypeChecks.CheckerTestCase do
  # See https://github.com/gyson/ex_type/issues/47
  _currently_failing_tests = """
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
  """

  @spec identity_int(integer()) :: integer()
  def identity_int(x) do
    x
  end
end
