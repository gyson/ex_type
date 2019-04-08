defimpl Inspect, for: Macro.Env do
  @moduledoc false

  def inspect(_env, _opts) do
    "%Macro.Env{}"
  end
end

defmodule ExType.Helper do
  defmacro __using__(_opts) do
    quote do
      require ExType.Helper
      alias ExType.Helper
    end
  end

  defmacro inspect(item, opts \\ []) do
    quote do
      IO.puts("-------------------------------------------------")
      IO.puts("Helper.inspect at #{__ENV__.file}:#{__ENV__.line}")
      IO.inspect(unquote(item), unquote(opts))
      IO.puts("-------------------------------------------------")
    end
  end
end
