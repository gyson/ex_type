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

  defmacro throw(options) do
    quote bind_quoted: [options: options] do
      file =
        case Keyword.fetch(options, :context) do
          {:ok, context} -> context.env.file
          :error -> "unknown_file"
        end

      line =
        with {:ok, meta} <- Keyword.fetch(options, :meta),
             {:ok, line} <- Keyword.fetch(meta, :line) do
          line
        else
          :error -> "?"
        end

      throw(%{
        message: Keyword.get(options, :message, "unknown message"),
        location: "#{file}:#{line}",
        debug_location: "#{__ENV__.file}:#{__ENV__.line}",
        unmatch: Keyword.get(options, :unmatch, false)
      })
    end
  end

  def stacktrace() do
    case Process.info(self(), :current_stacktrace) do
      {:current_stacktrace, [{Process, :info, _, _}, {ExType.Helper, :stacktrace, _, _} | rest]} ->
        rest
        |> Enum.map(fn {mod_name, fun_name, arity, info} ->
          file = Keyword.fetch!(info, :file)
          line = Keyword.fetch!(info, :line)
          "#{mod_name}.#{fun_name}/#{arity} at #{file}:#{line}"
        end)
        |> Enum.join("\n")
        |> IO.puts()
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

  def is_struct(module) when is_atom(module) do
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
