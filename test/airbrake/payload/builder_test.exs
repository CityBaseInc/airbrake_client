defmodule Airbrake.Payload.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Airbrake.Test.DataGenerator

  alias Airbrake.Payload.Builder

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "build/1 :context" do
    property "builds default/initial context using env and hostname from config" do
      opts = [config: MockConfig]

      check all context_environment <- context_environment(),
                hostname <- hostname() do
        MockConfig
        |> stub(:context_environment, fn -> context_environment end)
        |> stub(:hostname, fn -> hostname end)
        |> stub(:get, fn :filter_parameters, _ -> [] end)

        assert Builder.build(:context, opts) ==
                 %{environment: context_environment, hostname: hostname}
      end
    end

    property "can add more context" do
      check all context_environment <- context_environment(),
                hostname <- hostname(),
                foo <- one_of([integer(), string(:alphanumeric)]),
                bar <- one_of([integer(), string(:alphanumeric)]) do
        MockConfig
        |> stub(:context_environment, fn -> context_environment end)
        |> stub(:hostname, fn -> hostname end)
        |> stub(:get, fn :filter_parameters, _ -> [] end)

        opts = [
          config: MockConfig,
          context: %{foo: foo, bar: bar}
        ]

        assert Builder.build(:context, opts) == %{
                 environment: context_environment,
                 hostname: hostname,
                 foo: foo,
                 bar: bar
               }
      end
    end

    property "can add more context with keyword list" do
      check all context_environment <- context_environment(),
                hostname <- hostname(),
                foo <- one_of([integer(), string(:alphanumeric)]),
                bar <- one_of([integer(), string(:alphanumeric)]) do
        MockConfig
        |> stub(:context_environment, fn -> context_environment end)
        |> stub(:hostname, fn -> hostname end)
        |> stub(:get, fn :filter_parameters, _ -> [] end)

        opts = [
          config: MockConfig,
          context: [foo: foo, bar: bar]
        ]

        assert Builder.build(:context, opts) == %{
                 environment: context_environment,
                 hostname: hostname,
                 foo: foo,
                 bar: bar
               }
      end
    end

    property "context in opts overwrites defaults" do
      check all context_environment <- context_environment(),
                hostname <- hostname(),
                opts_context_environment <- context_environment(),
                opts_hostname <- hostname(),
                foo <- integer() do
        MockConfig
        |> stub(:context_environment, fn -> context_environment end)
        |> stub(:hostname, fn -> hostname end)
        |> stub(:get, fn :filter_parameters, _ -> [] end)

        opts = [
          config: MockConfig,
          context: %{foo: foo, environment: opts_context_environment, hostname: opts_hostname}
        ]

        assert Builder.build(:context, opts) == %{
                 environment: opts_context_environment,
                 hostname: opts_hostname,
                 foo: foo
               }
      end
    end
  end

  describe "build/1 :context filtering" do
    setup do
      MockConfig
      |> stub(:context_environment, fn -> "test" end)
      |> stub(:hostname, fn -> "test-host" end)

      :ok
    end

    test "applies :filter_parameters to context, recursively, preserving top-level keys" do
      stub(MockConfig, :get, fn :filter_parameters, _ -> ["email", "password"] end)

      opts = [
        config: MockConfig,
        context: %{
          email: "jane.doe@example.com",
          url: "https://example.test/pay",
          nested: %{"password" => "hunter2", "ok" => 1}
        }
      ]

      assert Builder.build(:context, opts) == %{
               environment: "test",
               hostname: "test-host",
               email: "[FILTERED]",
               url: "https://example.test/pay",
               nested: %{"password" => "[FILTERED]", "ok" => 1}
             }
    end

    test "leaves context unchanged when :filter_parameters is empty" do
      stub(MockConfig, :get, fn :filter_parameters, _ -> [] end)

      opts = [config: MockConfig, context: %{email: "jane.doe@example.com"}]

      assert Builder.build(:context, opts) == %{
               environment: "test",
               hostname: "test-host",
               email: "jane.doe@example.com"
             }
    end

    test "filters all cookie values by default, keeping cookie names" do
      stub(MockConfig, :get, fn :filter_parameters, _ -> [] end)

      opts = [
        config: MockConfig,
        context: %{cookies: %{"_app_session" => "fake-session-token", "tracking" => "abc123"}}
      ]

      assert %{cookies: %{"_app_session" => "[FILTERED]", "tracking" => "[FILTERED]"}} =
               Builder.build(:context, opts)
    end

    test "filters cookie values under a string key and in an associative list" do
      stub(MockConfig, :get, fn :filter_parameters, _ -> [] end)

      opts = [config: MockConfig, context: %{"cookies" => [{"_app_session", "fake-session-token"}]}]

      assert %{"cookies" => [{"_app_session", "[FILTERED]"}]} = Builder.build(:context, opts)
    end

    test "filters a non-map cookie value entirely" do
      stub(MockConfig, :get, fn :filter_parameters, _ -> [] end)

      opts = [config: MockConfig, context: %{cookies: "_app_session=fake-session-token"}]

      assert %{cookies: "[FILTERED]"} = Builder.build(:context, opts)
    end

    test "keeps nil cookies as nil" do
      stub(MockConfig, :get, fn :filter_parameters, _ -> [] end)

      opts = [config: MockConfig, context: %{cookies: nil}]

      assert %{cookies: nil} = Builder.build(:context, opts)
    end
  end

  describe "build/1 :environment" do
    test "returns nil if unspecified" do
      opts = []

      assert is_nil(Builder.build(:environment, opts))
    end

    property "returns value from opts" do
      check all environment <- map_of(atom(:alphanumeric), string(:alphanumeric)) do
        opts = [
          environment: environment
        ]

        assert Builder.build(:environment, opts) == environment
      end
    end

    property "can specify with deprecated :env key" do
      check all environment <- map_of(atom(:alphanumeric), string(:alphanumeric)) do
        opts = [
          env: environment
        ]

        assert Builder.build(:environment, opts) == environment
      end
    end

    property "returns keyword list from opts as map" do
      check all environment <- keyword_of(string(:alphanumeric)) do
        opts = [
          environment: environment
        ]

        assert Builder.build(:environment, opts) == Map.new(environment)
      end
    end

    property "filters headers" do
      check all headers1 <- map_of(string_key(), string(:alphanumeric)),
                headers2 <- map_of(string_key(), string(:alphanumeric)),
                headers = Map.merge(headers1, headers2) do
        # filter keys in headers1
        stub(MockConfig, :get, fn :filter_headers, _ -> Map.keys(headers1) end)
        stub(MockConfig, :payload_processor, fn -> Airbrake.PoisonPayloadProcessor end)

        opts = [
          config: MockConfig,
          environment: %{headers: headers}
        ]

        assert %{headers: filtered_headers} = Builder.build(:environment, opts)

        assert filtered_headers
               |> Map.take(Map.keys(headers1))
               |> Map.values()
               |> Enum.all?(&(&1 == "[FILTERED]"))

        assert filtered_headers |> Map.take(Map.keys(headers2)) |> Enum.all?(fn {k, v} -> v == Map.get(headers, k) end)
      end
    end
  end

  describe "build/1 :params" do
    test "returns nil if unspecified" do
      opts = []

      assert is_nil(Builder.build(:params, opts))
    end

    property "returns value from opts" do
      check all params <- map_of(string_key(), string(:alphanumeric)) do
        opts = [
          params: params
        ]

        assert Builder.build(:params, opts) == params
      end
    end

    property "filters params" do
      # NOTE: this does NOT test nested filtering.
      # That's tested with the Util function.

      check all params1 <- map_of(string_key(), string(:alphanumeric)),
                params2 <- map_of(string_key(), string(:alphanumeric)),
                params = Map.merge(params1, params2) do
        # filter keys in params1
        stub(MockConfig, :get, fn :filter_parameters, _ -> Map.keys(params1) end)
        stub(MockConfig, :payload_processor, fn -> Airbrake.PoisonPayloadProcessor end)

        opts = [
          config: MockConfig,
          params: params
        ]

        assert %{} = filtered_params = Builder.build(:params, opts)

        assert filtered_params
               |> Map.take(Map.keys(params1))
               |> Map.values()
               |> Enum.all?(&(&1 == "[FILTERED]"))

        assert filtered_params |> Map.take(Map.keys(params2)) |> Enum.all?(fn {k, v} -> v == Map.get(params, k) end)
      end
    end
  end

  describe "build/1 :session and Logger metadata" do
    test "nil if logger metadata is empty and :session not set" do
      session_includes_metadata()

      opts = [
        config: MockConfig,
        logger_metadata: []
      ]

      assert Builder.build(:session, opts) == nil
    end

    test "nil if logger metadata is nil and :session not set" do
      session_includes_metadata()

      opts = [
        config: MockConfig
      ]

      assert Builder.build(:session, opts) == nil
    end

    property "returns :session from opts over logger metadata" do
      session_includes_metadata()

      check all logger_metadata <- keyword_of(string(:alphanumeric)),
                session <- map_of(string_key(), string(:alphanumeric)),
                logger_metadata != [] or session != %{} do
        opts = [
          config: MockConfig,
          logger_metadata: logger_metadata,
          session: session
        ]

        assert Builder.build(:session, opts) ==
                 Map.merge(Map.new(logger_metadata), session)
      end
    end

    defp session_includes_metadata do
      MockConfig
      |> stub(:get, fn :session -> :include_logger_metadata end)
      |> stub(:get, fn :filter_parameters, _ -> [] end)
    end
  end

  describe "build/1 :session WITHOUT Logger metadata" do
    property "nil if :session not set regardless of Logger metadata" do
      session_does_not_includes_metadata()

      check all logger_metadata <- keyword_of(string(:alphanumeric)) do
        opts = [
          config: MockConfig,
          logger_metadata: logger_metadata
        ]

        assert Builder.build(:session, opts) == nil
      end
    end

    property "returns :session from opts only" do
      session_does_not_includes_metadata()

      check all logger_metadata <- keyword_of(string(:alphanumeric)),
                session <- map_of(string_key(), string(:alphanumeric)),
                session != %{} do
        opts = [
          config: MockConfig,
          logger_metadata: logger_metadata,
          session: session
        ]

        assert Builder.build(:session, opts) == session
      end
    end

    defp session_does_not_includes_metadata do
      MockConfig
      |> stub(:get, fn :session -> nil end)
      |> stub(:get, fn :filter_parameters, _ -> [] end)
    end
  end

  describe "build/1 :session filtering" do
    test "applies :filter_parameters to Logger metadata and session, recursively" do
      MockConfig
      |> stub(:get, fn :session -> :include_logger_metadata end)
      |> stub(:get, fn :filter_parameters, _ -> ["payer_email", "email_id", "password"] end)

      opts = [
        config: MockConfig,
        logger_metadata: [payer_email: "jane.doe@example.com", request_id: "req-123"],
        session: %{"email_id" => "john.roe@example.com", "user" => %{"password" => "hunter2", "id" => 42}}
      ]

      assert Builder.build(:session, opts) == %{
               :payer_email => "[FILTERED]",
               :request_id => "req-123",
               "email_id" => "[FILTERED]",
               "user" => %{"password" => "[FILTERED]", "id" => 42}
             }
    end

    test "applies :filter_parameters to session without Logger metadata" do
      MockConfig
      |> stub(:get, fn :session -> nil end)
      |> stub(:get, fn :filter_parameters, _ -> ["cashier_email"] end)

      opts = [
        config: MockConfig,
        logger_metadata: [cashier_email: "jane.doe@example.com"],
        session: %{cashier_email: "john.roe@example.com", till: 7}
      ]

      assert Builder.build(:session, opts) == %{cashier_email: "[FILTERED]", till: 7}
    end
  end

  describe "filter_environment/2 cookie header" do
    test "always filters the cookie header" do
      stub(MockConfig, :get, fn :filter_headers, _ -> [] end)
      stub(MockConfig, :payload_processor, fn -> Airbrake.PoisonPayloadProcessor end)

      result =
        Builder.filter_environment(
          %{headers: %{"cookie" => "_app_session=fake-session-token", "accept" => "*/*"}},
          config: MockConfig
        )

      assert result == %{headers: %{"cookie" => "[FILTERED]", "accept" => "*/*"}}
    end
  end

  describe "filter_environment/2 with payload_processor" do
    test "uses the configured payload processing module for string headers" do
      stub(MockConfig, :get, fn :filter_headers, _ -> ["authorization"] end)
      stub(MockConfig, :payload_processor, fn -> Airbrake.MockPayloadProcessor end)

      stub(Airbrake.MockPayloadProcessor, :process_headers, fn _headers, _opts ->
        {:filtered, "from MockPayloadProcessor"}
      end)

      result = Builder.filter_environment(%{"headers" => %{"authorization" => "Bearer token"}}, config: MockConfig)

      assert result == %{"headers" => {:filtered, "from MockPayloadProcessor"}}
    end

    test "uses the configured payload processing module for atom headers" do
      stub(MockConfig, :get, fn :filter_headers, _ -> ["authorization"] end)
      stub(MockConfig, :payload_processor, fn -> Airbrake.MockPayloadProcessor end)

      stub(Airbrake.MockPayloadProcessor, :process_headers, fn _headers, _opts ->
        {:filtered, "from MockPayloadProcessor"}
      end)

      result = Builder.filter_environment(%{headers: %{"authorization" => "Bearer token"}}, config: MockConfig)

      assert result == %{headers: {:filtered, "from MockPayloadProcessor"}}
    end

    test "uses JasonPayloadProcessor when configured" do
      stub(MockConfig, :get, fn :filter_headers, _ -> ["authorization"] end)
      stub(MockConfig, :payload_processor, fn -> Airbrake.JasonPayloadProcessor end)

      result = Builder.filter_environment(%{"headers" => %{"authorization" => "Bearer token"}}, config: MockConfig)

      assert result == %{"headers" => %{"authorization" => "[FILTERED]"}}
    end
  end
end
