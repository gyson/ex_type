defmodule ExType.Emoji do
  @moduledoc false

  def error(), do: "❗"

  def inspect(), do: "❔"

  def warning(), do: "⚠️"

  def one_test_pass(), do: "✅"

  def one_test_fail(), do: "❌"

  def all_test_pass(), do: "💜 💜 💜"

  def any_test_fail(), do: "🔥 🔥 🔥"
end
