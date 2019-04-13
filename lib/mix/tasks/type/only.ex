defmodule Mix.Tasks.Type.Only do
  use Mix.Task

  # `mix type.only Enum` for single module
  # `mix type.only Enum.map` for single function
  # `mix type.only Enum.map/2` for single function with specified arity
  def run([name]) do
    filter = ExType.Filter.parse(name)

    # could run in parallel
    for file <- Mix.Tasks.Type.get_files() do
      ExType.Filter.register_filter(file, filter)
      ExType.check(file)
    end
  end
end
