defmodule Airbrake.Mixfile do
  use Mix.Project

  def project do
    [app: :airbrake,
     version: "0.6.0",
     elixir: "~> 1.2",
     package: package(),
     description: """
       The first Elixir notifier to the Airbrake/Errbit.
       System-wide error reporting enriched with the information from Plug and Phoenix channels.
     """,
     deps: deps(),
     docs: [main: "Airbrake"]]
  end

  def package do
    [contributors: ["Roman Smirnov", "CityBase Inc"],
     maintainers: ["Roman Smirnov"],
     licenses: ["LGPL"],
     links: %{github: "https://github.com/CityBaseInc/airbrake-elixir"}]
  end

  def application do
    [mod: {Airbrake, []}, applications: [:httpoison]]
  end

  defp deps do
    [{:httpoison, "~> 0.9 or ~> 1.0"},
     {:poison, "~> 2.0 or ~> 3.0 or ~> 3.1"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
