defmodule ExType.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_type,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]]
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
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths() do
    case Mix.env() do
      :test -> ["lib", "test"]
      _ -> ["lib"]
    end
  end
end
