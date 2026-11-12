defmodule Airbrake.Payload.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Airbrake.Test.DataGenerator

  alias Airbrake.Payload.Builder

  defmodule User do
    @moduledoc false
    defstruct [:name, :password]
  end

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
                logger_metadata != [] or session != %{},
                not Enum.any?(logger_metadata, fn {key, _} -> Map.has_key?(session, Atom.to_string(key)) end) do
        opts = [
          config: MockConfig,
          logger_metadata: logger_metadata,
          session: session
        ]

        assert Builder.build(:session, opts) ==
                 logger_metadata |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end) |> Map.merge(session)
      end
    end

    test "returns logger metadata if :session is nil" do
      session_includes_metadata()

      opts = [
        config: MockConfig,
        logger_metadata: [request_id: "abc123"],
        session: nil
      ]

      assert Builder.build(:session, opts) == %{"request_id" => "abc123"}
    end

    test "filters logger metadata and :session" do
      session_includes_metadata(["email", "token"])

      opts = [
        config: MockConfig,
        logger_metadata: [email: "alice@example.com", request_id: "abc123"],
        session: %{"token" => "secret", "user_id" => 42}
      ]

      assert Builder.build(:session, opts) == %{
               "email" => "[FILTERED]",
               "request_id" => "abc123",
               "token" => "[FILTERED]",
               "user_id" => 42
             }
    end

    defp session_includes_metadata(filter_parameters \\ []) do
      stub(MockConfig, :get, fn :session -> :include_logger_metadata end)
      stub_session_processing(filter_parameters)
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

    test "nil if :session is nil" do
      session_does_not_includes_metadata()

      assert Builder.build(:session, config: MockConfig, session: nil) == nil
    end

    test "destructures structs, filters, and converts tuples to lists" do
      session_does_not_includes_metadata(["password"])

      opts = [
        config: MockConfig,
        session: %{current_user: %User{name: "Alice", password: "secret"}, position: {1, 2}}
      ]

      assert Builder.build(:session, opts) == %{
               "current_user" => %{"name" => "Alice", "password" => "[FILTERED]"},
               "position" => [1, 2]
             }
    end

    test "uses the configured payload processor" do
      session_does_not_includes_metadata()
      stub(MockConfig, :get, fn :filter_parameters, _ -> ["password"] end)
      stub(MockConfig, :payload_processor, fn -> Airbrake.MockPayloadProcessor end)

      expect(Airbrake.MockPayloadProcessor, :process_params, fn session, opts ->
        assert session == %{"password" => "secret"}
        assert opts == [filtered_attributes: ["password"]]
        {:processed, "from MockPayloadProcessor"}
      end)

      opts = [config: MockConfig, session: %{"password" => "secret"}]

      assert Builder.build(:session, opts) == {:processed, "from MockPayloadProcessor"}
    end

    defp session_does_not_includes_metadata(filter_parameters \\ []) do
      stub(MockConfig, :get, fn :session -> nil end)
      stub_session_processing(filter_parameters)
    end
  end

  defp stub_session_processing(filter_parameters) do
    MockConfig
    |> stub(:get, fn :filter_parameters, _ -> filter_parameters end)
    |> stub(:payload_processor, fn -> Airbrake.JsonPayloadProcessor end)
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
