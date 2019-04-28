defmodule ExType.Debug do
  def set() do
    :persistent_term.put(ExType.Debug, true)
  end

  def enabled?() do
    try do
      :persistent_term.get(ExType.Debug)
    rescue
      ArgumentError -> false
      # for old version without persistent_term support
      UndefinedFunctionError -> false
    end
  end
end
