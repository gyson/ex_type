defmodule ExType.CheckerTestCase do
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

  @spec test_case_3() :: integer()

  def test_case_3 do
    23
  end

  @spec test_case_4(t) :: t when t: var

  def test_case_4(t) do
    t
  end
end
