defmodule Foo do
  @spec foo(t) :: %{ :foo => t, :bar => t } when t: any()

  def foo(t) do
    %{foo: t, bar: t}
  end
end
