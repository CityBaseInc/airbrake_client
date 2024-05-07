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
        stub(MockConfig, :get, fn
          :environment -> environment
          :context_environment -> context_environment
        end)

        assert Config.context_environment(MockConfig) == context_environment
        assert Config.context_environment(MockConfig) != environment
      end
    end

    property "returns string from :environment of config" do
      check all environment <- context_environment() do
        stub(MockConfig, :get, fn
          :environment -> environment
          :context_environment -> nil
        end)

        assert Config.context_environment(MockConfig) == environment
      end
    end
  end
end
