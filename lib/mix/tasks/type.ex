defmodule Mix.Tasks.Type do
  use Mix.Task

  def run([]) do
    prepare()

    # could run in parallel
    for file <- get_files() do
      ExType.check(file)
    end
  end

  # `mix type Enum` for single module
  # `mix type Enum.map` for single function
  # `mix type Enum.map/2` for single function with specified arity
  def run([filter]) when is_binary(filter) do
    prepare()

    filter = ExType.Filter.parse(filter)
    ExType.Filter.register(filter)

    # could run in parallel
    for file <- get_files() do
      ExType.check(file)
    end
  end

  defp prepare() do
    Mix.Task.run "loadpaths", []
  end

  defp get_files() do
    cwd = File.cwd!()

    type_exs = Path.join(cwd, "type.exs")

    config =
      if File.exists?(type_exs) do
        type_exs
        |> Code.eval_file()
        |> elem(0)
      else
        []
      end

    includes =
      Keyword.get(config, :include, ["lib/**/*.ex"])
      |> Enum.flat_map(fn glob -> Path.wildcard(Path.join(cwd, glob)) end)
      |> Enum.into(MapSet.new())

    excludes =
      Keyword.get(config, :exclude, [])
      |> Enum.flat_map(fn glob -> Path.wildcard(Path.join(cwd, glob)) end)
      |> Enum.into(MapSet.new())

    MapSet.difference(includes, excludes)
  end
end
