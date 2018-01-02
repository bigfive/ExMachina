defmodule Exmachina.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exmachina,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :numerix]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:numerix, "~> 0.4"}]
  end
end
