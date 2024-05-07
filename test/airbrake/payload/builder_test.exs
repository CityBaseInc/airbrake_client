defmodule Airbrake.Payload.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Airbrake.Test.DataGenerator

  alias Airbrake.Payload.Builder

  setup :verify_on_exit!

  describe "build/1 :context" do
    property "builds default/initial context using env and hostname from config" do
      opts = [config: MockConfig]

      check all env <- env(),
                hostname <- hostname() do
        MockConfig
        |> stub(:env, fn -> env end)
        |> stub(:hostname, fn -> hostname end)

        assert Builder.build(:context, opts) == %{environment: env, hostname: hostname}
      end
    end

    property "can add more context" do
      check all env <- env(),
                hostname <- hostname(),
                foo <- one_of([integer(), string(:alphanumeric)]),
                bar <- one_of([integer(), string(:alphanumeric)]) do
        MockConfig
        |> stub(:env, fn -> env end)
        |> stub(:hostname, fn -> hostname end)

        opts = [
          config: MockConfig,
          context: %{foo: foo, bar: bar}
        ]

        assert Builder.build(:context, opts) == %{
                 environment: env,
                 hostname: hostname,
                 foo: foo,
                 bar: bar
               }
      end
    end

    property "can add more context with keyword list" do
      check all env <- env(),
                hostname <- hostname(),
                foo <- one_of([integer(), string(:alphanumeric)]),
                bar <- one_of([integer(), string(:alphanumeric)]) do
        MockConfig
        |> stub(:env, fn -> env end)
        |> stub(:hostname, fn -> hostname end)

        opts = [
          config: MockConfig,
          context: [foo: foo, bar: bar]
        ]

        assert Builder.build(:context, opts) == %{
                 environment: env,
                 hostname: hostname,
                 foo: foo,
                 bar: bar
               }
      end
    end

    property "context in opts overwrites defaults" do
      check all env <- env(),
                hostname <- hostname(),
                opts_env <- env(),
                opts_hostname <- hostname(),
                foo <- integer() do
        MockConfig
        |> stub(:env, fn -> env end)
        |> stub(:hostname, fn -> hostname end)

        opts = [
          config: MockConfig,
          context: %{foo: foo, environment: opts_env, hostname: opts_hostname}
        ]

        assert Builder.build(:context, opts) == %{
                 environment: opts_env,
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
      stub(MockConfig, :get, fn :session -> :include_logger_metadata end)
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
      stub(MockConfig, :get, fn :session -> nil end)
    end
  end
end
