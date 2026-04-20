defmodule Airbrake.ConfigTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Airbrake.Test.DataGenerator
  import Mox

  alias Airbrake.Config

  setup :set_mox_from_context
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

  describe "payload_processor/1" do
    test "returns the module when :payload_processor is set" do
      MockConfig
      |> stub(:get, fn :payload_processor -> Airbrake.JasonPayloadProcessor end)

      assert Config.payload_processor(MockConfig) == Airbrake.JasonPayloadProcessor
    end

    test "falls back to Jason module when :json_encoder is Jason" do
      MockConfig
      |> stub(:get, fn
        :payload_processor -> nil
        :json_encoder -> Jason
      end)

      assert Config.payload_processor(MockConfig) == Airbrake.JasonPayloadProcessor
    end

    test "falls back to Json module when :json_encoder is :json" do
      MockConfig
      |> stub(:get, fn
        :payload_processor -> nil
        :json_encoder -> :json
      end)

      assert Config.payload_processor(MockConfig) == Airbrake.JsonPayloadProcessor
    end

    test "falls back to Poison module when :json_encoder is Poison" do
      MockConfig
      |> stub(:get, fn
        :payload_processor -> nil
        :json_encoder -> Poison
      end)

      assert Config.payload_processor(MockConfig) == Airbrake.PoisonPayloadProcessor
    end

    test "defaults to Poison module when neither is configured" do
      MockConfig
      |> stub(:get, fn
        :payload_processor -> nil
        :json_encoder -> nil
      end)

      assert Config.payload_processor(MockConfig) == Airbrake.PoisonPayloadProcessor
    end
  end

  describe "project_id/1" do
    test "returns integer project_id unchanged" do
      MockConfig
      |> stub(:get, fn :project_id -> 12_345 end)

      assert Config.project_id(MockConfig) == 12_345
    end

    test "converts string project_id to integer" do
      MockConfig
      |> stub(:get, fn :project_id -> "12345" end)

      assert Config.project_id(MockConfig) == 12_345
    end
  end

  defp random_environment do
    string(:alphanumeric, min_length: 1)
  end
end
