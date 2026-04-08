defmodule DefaultProcessorApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :default_processor_app,
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
      {:poison, ">= 2.0.0"}
    ]
  end
end
