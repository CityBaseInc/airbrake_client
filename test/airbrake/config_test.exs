defmodule Airbrake.ConfigTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Airbrake.Config

  import Airbrake.Test.DataGenerator
  import Mox

  setup :verify_on_exit!

  describe "context_environment/0" do
    property "returns string from :context_environment of config" do
      check all context_environment <- context_environment(),
                environment <- context_environment(),
                context_environment != environment do
        MockConfig
        |> stub(:get, fn
          :environment -> environment
          :context_environment -> context_environment
        end)
        |> stub(:get, fn :production_aliases, [] -> [] end)

        assert Config.context_environment(MockConfig) == context_environment
        assert Config.context_environment(MockConfig) != environment
      end
    end

    property "returns string from :environment of config" do
      check all environment <- context_environment() do
        MockConfig
        |> stub(:get, fn
          :environment -> environment
          :context_environment -> nil
        end)
        |> stub(:get, fn :production_aliases, [] -> [] end)

        assert Config.context_environment(MockConfig) == environment
      end
    end

    property "translates production_aliases to production" do
      check all production_environments <- list_of(random_environment(), min_length: 10),
                context_environment <- member_of(production_environments) do
        MockConfig
        |> stub(:get, fn :context_environment -> context_environment end)
        |> stub(:get, fn :production_aliases, [] -> production_environments end)

        assert Config.context_environment(MockConfig) == "production"
      end
    end

    property "no translation if not in production_aliases" do
      check all production_environments <- list_of(random_environment(), min_length: 10),
                context_environment <- random_environment(),
                context_environment not in production_environments do
        MockConfig
        |> stub(:get, fn :context_environment -> context_environment end)
        |> stub(:get, fn :production_aliases, [] -> production_environments end)

        assert Config.context_environment(MockConfig) == context_environment
      end
    end
  end

  defp random_environment do
    string(:alphanumeric, min_length: 1)
  end
end
