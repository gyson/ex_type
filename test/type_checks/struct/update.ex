defmodule TypeChecks.Struct.Update do
  defmodule Foo do
    defstruct [:foo]
  end

  @spec foo(t) :: %Foo{ foo: t } when t: any()
  def foo(t) do
    value = %Foo{}
    %Foo{value | foo: t}
  end
end
