defmodule Pulsar.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pulsar,
      version: "0.2.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),

      description: description(),
      source_url: "https://github.com/walmartlabs/pulsar",
      name: "Pulsar",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Pulsar.Application, nil},
      registered: [Pulsar.DashboardServer],
      env: [
        flush_interval: 100,
        active_highlight_duration: 1000
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end

  defp package do
    [
      maintainers: ["Howard M. Lewis Ship"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/walmartlabs/pulsar"}
    ]
  end

  defp description() do
    """
    A text-based, dynamic dashboard. Jobs update in place, using xterm command codes.
    """
  end

  def docs() do
    [
      source_url: "http://github.com/walmartlabs/pulsar",
      extras: ["README.md", "CHANGES.md"],
      assets: "assets"
    ]
  end
end
