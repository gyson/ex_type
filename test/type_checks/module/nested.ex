defmodule TypeChecks.Module.Nested do
  # Regression test for https://github.com/gyson/ex_type/issues/23
  defmodule Nested do
    @enforce_keys [:nested]
    defstruct @enforce_keys

    @type t(nested) :: %Nested{
      nested: nested
    }
  end

  @spec get_nested(Nested.t(nested)) :: nested when nested: any()
  def get_nested(%Nested{nested: nested}) do
    nested
  end
end
