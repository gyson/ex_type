defmodule ExType.Helper do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      alias ExType.Checker
      alias ExType.Context
      alias ExType.CustomEnv
      alias ExType.Type
      alias ExType.Helper
      alias ExType.Typespec
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

  defmacro spec_error(spec, type, context) do
    quote do
      {:error,
       %ExType.Unification.SpecError{
         spec: unquote(spec),
         type: unquote(type),
         context: unquote(context),
         line: "#{__ENV__.file}:#{__ENV__.line}"
       }}
    end
  end

  defmacro pattern_error(pattern, type, context) do
    quote do
      {:error,
       %ExType.Unification.PatternError{
         pattern: unquote(pattern),
         type: unquote(type),
         context: unquote(context),
         line: "#{__ENV__.file}:#{__ENV__.line}"
       }}
    end
  end

  defmacro eval_error(code, context) do
    quote do
      {:error,
       %ExType.Checker.EvalError{
         code: unquote(code),
         context: unquote(context),
         line: "#{__ENV__.file}:#{__ENV__.line}"
       }}
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
end

defimpl Inspect, for: Macro.Env do
  @moduledoc false

  def inspect(_env, _opts) do
    "%Macro.Env{}"
  end
end
