defmodule ExType.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_type,
      version: "0.2.1",
      description: "A type checker for Elixir",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(),
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      name: "ExType",
      source_url: "https://github.com/gyson/ex_type"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_type_runtime, "~> 0.1.0"},
      {:ex_doc, "~> 0.20.2", only: :dev, runtime: false},
      {:dialyxir, github: "jeremyjh/dialyxir", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths() do
    case Mix.env() do
      :test -> ["lib", "test"]
      _ -> ["lib"]
    end
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/gyson/ex_type"}
    }
  end
end
