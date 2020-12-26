defmodule ExType.CheckerTestCase do
  require ExType.T
  alias ExType.T

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

  @spec test_case_3() :: integer()

  def test_case_3 do
    23
  end

  @spec test_case_4(t) :: t when t: var

  def test_case_4(t) do
    t
  end

  # Regression test for https://github.com/gyson/ex_type/issues/23
  defmodule Nested do
    @enforce_keys [:nested]
    defstruct @enforce_keys

    @type t(nested) :: %Nested{
      nested: nested
    }
  end

  # FIXME Would be great to have your input how you want to name test cases :)
  @spec get_nested(Nested.t(nested)) :: nested when nested: any()

  def get_nested(%Nested{nested: nested}) do
    nested
  end
end
