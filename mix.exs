defmodule Airbrake.Mixfile do
  use Mix.Project

  def project do
    [
      app: :airbrake_client,
      version: "2.2.1",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      aliases: aliases(),
      description: """
        Elixir notifier to Airbrake.io (or Errbit) with plugs for Phoenix for automatic reporting.
      """,
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [mod: {Airbrake, []}]
  end

  def cli do
    [
      preferred_envs: [
        all_tests: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def package do
    [
      contributors: ["Jeremy D. Frens", "Clifton McIntosh", "Roman Smirnov"],
      maintainers: ["Euna Payments"],
      licenses: ["LGPL"],
      links: %{github: "https://github.com/CityBaseInc/airbrake_client"}
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

  defp deps do
    [
      {:httpoison, "~> 1.0 or ~> 2.0"},
      {:jason, ">= 1.0.0", optional: true},
      {:poison, ">= 2.0.0", optional: true},
      # dev and test
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.2", only: [:dev, :test]}
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
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/payload_processor.md",
        "guides/ignoring_errors.md",
        "guides/shared_options.md",
        "guides/context_environment.md",
        "guides/session.md",
        "guides/developing.md",
        "guides/migrating.md"
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md", "README.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
