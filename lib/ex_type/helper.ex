defmodule ExType.Helper do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      alias ExType.Checker
      alias ExType.Context
      alias ExType.CustomEnv
      alias ExType.Type
      alias ExType.Emoji
      alias ExType.Helper
      alias ExType.Parser
      alias ExType.Typespec
      alias ExType.Typespecable
      alias ExType.Unification

      require ExType.Helper
    end
  end

  defmacro inspect(item, opts \\ []) do
    quote bind_quoted: [item: item, opts: opts] do
      IO.puts("-------------------------------------------------")
      IO.puts("Helper.inspect at #{__ENV__.file}:#{__ENV__.line}")
      IO.inspect(item, opts)
      IO.puts("-------------------------------------------------")
      item
    end
  end

  defmacro throw(message) do
    quote do
      throw("#{unquote(message)} at #{__ENV__.file}:#{__ENV__.line}")
    end
  end

  def is_protocol(module) do
    try do
      module.__protocol__(:module)
      true
    rescue
      UndefinedFunctionError ->
        false
    end
  end

  def is_struct(module) do
    try do
      module.__struct__()
      true
    rescue
      UndefinedFunctionError ->
        false
    end
  end

  def is_exception(module) do
    try do
      Keyword.get(module.__info__(:attributes), :behaviour) == [Exception]
    rescue
      UndefinedFunctionError ->
        false
    end
  end

  def get_module(module) do
    ["ExType", "Module" | rest] = Module.split(module)
    Module.concat(rest)
  end
end
