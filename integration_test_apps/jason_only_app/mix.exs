defmodule JasonOnlyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :jason_only_app,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:airbrake_client, ">= 0.0.0", path: "../.."},
      {:jason, ">= 1.0.0"}
    ]
  end
end
