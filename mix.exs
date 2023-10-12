defmodule Airbrake.Mixfile do
  use Mix.Project

  def project do
    [
      app: :airbrake_client,
      version: "0.11.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      aliases: aliases(),
      description: """
        Elixir notifier to Airbrake.io (or Errbit) with plugs for Phoenix for automatic reporting.
      """,
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      preferred_cli_env: [
        all_tests: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      list_unused_filters: true
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  def package do
    [
      contributors: ["Jeremy D. Frens", "Clifton McIntosh", "Roman Smirnov"],
      maintainers: ["CityBase, Inc."],
      licenses: ["LGPL"],
      links: %{github: "https://github.com/CityBaseInc/airbrake_client"}
    ]
  end

  def application do
    [mod: {Airbrake, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # 1.4 is not compilable with Elixir <1.12.
      # For test CI, we just need to _compile_ dialyxir on earlier versions.
      {:dialyxir, "~> 1.3.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:httpoison, "~> 1.0 or ~> 2.0"},
      {:jason, ">= 1.0.0", optional: true},
      {:mox, "~> 1.1", only: :test},
      {:poison, ">= 2.0.0", optional: true},
      {:stream_data, "~> 0.6", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      test: "test --no-start",
      all_tests: [
        "compile --force --warnings-as-errors",
        "credo --strict",
        "format --check-formatted",
        "docs --output test/doc",
        "coveralls --raise",
        "dialyzer"
      ]
    ]
  end
end
