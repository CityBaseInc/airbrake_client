defmodule Airbrake.Config.ValidatorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Airbrake.Config.Validator

  @valid_config [api_key: "test_key", project_id: 123]

  defp config(overrides) do
    Keyword.merge(@valid_config, overrides)
  end

  describe "validate/1 with valid config" do
    test "passes with minimal required config" do
      assert :ok = Validator.validate(@valid_config)
    end

    test "passes with all optional keys" do
      warnings =
        capture_io(:stderr, fn ->
          assert :ok =
                   Validator.validate(
                     config(
                       host: "https://errbit.example.com",
                       payload_processor: Airbrake.JasonPayloadProcessor,
                       filter_parameters: ["password", "secret"],
                       filter_headers: ["authorization"],
                       production_aliases: ["prod", "production-us"],
                       session: :include_logger_metadata,
                       ignore: :all,
                       options: [context: %{app: "test"}],
                       context_environment: "staging",
                       private: [http_adapter: HTTPoison]
                     )
                   )
        end)

      assert warnings == ""
    end
  end

  describe "validate/1 unknown keys" do
    test "rejects an unknown key" do
      assert {:error, errors} = Validator.validate(config(banana: ["password"]))
      assert "unknown config key :banana" in errors
    end

    test "rejects multiple unknown keys" do
      assert {:error, errors} =
               Validator.validate(config(banana: ["password"], dinosaur: "https://example.com"))

      assert "unknown config key :banana" in errors
      assert "unknown config key :dinosaur" in errors
    end
  end

  describe "validate/1 required keys" do
    test "rejects missing api_key" do
      assert {:error, errors} = Validator.validate(project_id: 123)
      assert ":api_key is required" in errors
    end

    test "rejects missing project_id" do
      assert {:error, errors} = Validator.validate(api_key: "key")
      assert ":project_id is required" in errors
    end
  end

  describe "validate/1 type checks" do
    test "rejects non-string api_key" do
      assert {:error, errors} = Validator.validate(config(api_key: 123))
      assert ":api_key must be a string, got 123" in errors
    end

    test "accepts {:system, var} for api_key" do
      assert :ok = Validator.validate(config(api_key: {:system, "AIRBRAKE_API_KEY"}))
    end

    test "rejects non-integer, non-string project_id" do
      assert {:error, errors} = Validator.validate(config(project_id: :some_atom))
      assert ":project_id must be an integer or integer string, got :some_atom" in errors
    end

    test "accepts an integer string for project_id" do
      assert :ok = Validator.validate(config(project_id: "123"))
    end

    test "rejects a non-integer string for project_id" do
      assert {:error, errors} = Validator.validate(config(project_id: "abc"))
      assert ":project_id must be an integer or integer string, got \"abc\"" in errors
    end

    test "accepts {:system, var} for project_id" do
      assert :ok = Validator.validate(config(project_id: {:system, "AIRBRAKE_PROJECT_ID"}))
    end

    test "rejects non-string host" do
      assert {:error, errors} = Validator.validate(config(host: :localhost))
      assert ":host must be a string, got :localhost" in errors
    end

    test "rejects non-module json_encoder" do
      capture_io(:stderr, fn ->
        assert {:error, errors} = Validator.validate(config(json_encoder: "Jason"))
        assert ":json_encoder must be a module, got \"Jason\"" in errors
      end)
    end

    test "rejects non-list filter_parameters" do
      assert {:error, errors} = Validator.validate(config(filter_parameters: "password"))
      assert ":filter_parameters must be a list of strings, got \"password\"" in errors
    end

    test "rejects filter_parameters with non-string elements" do
      assert {:error, errors} = Validator.validate(config(filter_parameters: [:password]))
      assert ":filter_parameters must be a list of strings" in errors
    end

    test "rejects non-list filter_headers" do
      assert {:error, errors} = Validator.validate(config(filter_headers: :authorization))
      assert ":filter_headers must be a list of strings, got :authorization" in errors
    end

    test "rejects non-list production_aliases" do
      assert {:error, errors} = Validator.validate(config(production_aliases: "prod"))
      assert ":production_aliases must be a list of strings, got \"prod\"" in errors
    end

    test "rejects invalid session value" do
      assert {:error, errors} = Validator.validate(config(session: :always))
      assert ":session must be :include_logger_metadata or nil, got :always" in errors
    end

    test "rejects invalid ignore value" do
      assert {:error, errors} = Validator.validate(config(ignore: "SomeError"))
      assert Enum.any?(errors, &String.starts_with?(&1, ":ignore must be"))
    end

    test "accepts a MapSet for ignore" do
      assert :ok = Validator.validate(config(ignore: MapSet.new(["SomeError"])))
    end

    test "accepts a 2-arity function for ignore" do
      assert :ok = Validator.validate(config(ignore: fn _type, _message -> false end))
    end

    test "accepts a keyword list for options" do
      assert :ok = Validator.validate(config(options: [context: %{app: "test"}]))
    end

    test "accepts an MFA tuple for options" do
      assert :ok = Validator.validate(config(options: {MyApp, :airbrake_options, 1}))
    end

    test "rejects invalid options" do
      assert {:error, errors} = Validator.validate(config(options: "bad"))
      assert Enum.any?(errors, &String.starts_with?(&1, ":options must be"))
    end

    test "accepts a string for context_environment" do
      assert :ok = Validator.validate(config(context_environment: "staging"))
    end

    test "accepts an atom for context_environment" do
      assert :ok = Validator.validate(config(context_environment: :staging))
    end

    test "accepts {:system, var} for context_environment" do
      assert :ok = Validator.validate(config(context_environment: {:system, "ENVIRONMENT"}))
    end

    test "accepts a 0-arity function for context_environment" do
      assert :ok = Validator.validate(config(context_environment: fn -> "staging" end))
    end

    test "rejects invalid context_environment" do
      assert {:error, errors} = Validator.validate(config(context_environment: 42))
      assert Enum.any?(errors, &String.starts_with?(&1, ":context_environment must be"))
    end
  end

  describe "validate/1 :payload_processor" do
    test "accepts Airbrake.PoisonPayloadProcessor" do
      assert :ok = Validator.validate(config(payload_processor: Airbrake.PoisonPayloadProcessor))
    end

    test "accepts Airbrake.JasonPayloadProcessor" do
      assert :ok = Validator.validate(config(payload_processor: Airbrake.JasonPayloadProcessor))
    end

    if Code.ensure_loaded?(:json) do
      test "accepts Airbrake.JsonPayloadProcessor" do
        assert :ok = Validator.validate(config(payload_processor: Airbrake.JsonPayloadProcessor))
      end
    end

    test "rejects a non-module value" do
      assert {:error, errors} = Validator.validate(config(payload_processor: "NotAModule"))
      assert ":payload_processor must be a module, got \"NotAModule\"" in errors
    end

    test "rejects an unavailable module" do
      assert {:error, errors} = Validator.validate(config(payload_processor: NonExistent.Processing))
      assert ":payload_processor module NonExistent.Processing is not available" in errors
    end

    test "rejects a module missing callbacks" do
      assert {:error, errors} = Validator.validate(config(payload_processor: String))
      assert Enum.any?(errors, &String.contains?(&1, "is missing callbacks"))
    end
  end

  describe "validate/1 json_encoder availability" do
    test "rejects an unavailable json_encoder module" do
      capture_io(:stderr, fn ->
        assert {:error, errors} = Validator.validate(config(json_encoder: NonExistent.Encoder))
        assert "JSON encoder NonExistent.Encoder is not available" in errors
      end)
    end

    test "accepts an available json_encoder module" do
      capture_io(:stderr, fn ->
        assert :ok = Validator.validate(config(json_encoder: Jason))
      end)
    end

    test "skips json_encoder check when payload_processor is set" do
      assert :ok =
               Validator.validate(config(payload_processor: Airbrake.JasonPayloadProcessor))
    end

    test "warns when both json_encoder and payload_processor are set" do
      warning =
        capture_io(:stderr, fn ->
          Validator.validate(config(json_encoder: Jason, payload_processor: Airbrake.JasonPayloadProcessor))
        end)

      assert warning =~ ":json_encoder is ignored because :payload_processor is set to Airbrake.JasonPayloadProcessor"
    end

    test "does not error on unavailable json_encoder when payload_processor is set" do
      capture_io(:stderr, fn ->
        result =
          Validator.validate(
            config(json_encoder: NonExistent.Encoder, payload_processor: Airbrake.JasonPayloadProcessor)
          )

        send(self(), {:result, result})
      end)

      assert_received {:result, :ok}
    end
  end

  describe "validate/1 deprecations" do
    test "warns when :json_encoder is set" do
      warning =
        capture_io(:stderr, fn ->
          Validator.validate(config(json_encoder: Jason))
        end)

      assert warning =~ ":json_encoder is deprecated, use :payload_processor instead"
    end

    test "warns when :environment is set" do
      warning =
        capture_io(:stderr, fn ->
          Validator.validate(config(environment: "staging"))
        end)

      assert warning =~ ":environment is deprecated, use :context_environment instead"
    end

    test "does not warn when neither deprecated key is set" do
      warning =
        capture_io(:stderr, fn ->
          Validator.validate(@valid_config)
        end)

      refute warning =~ "is deprecated"
    end
  end

  describe "validate/1 multiple errors" do
    test "collects multiple errors at once" do
      assert {:error, errors} = Validator.validate(host: 42, banana: "value")
      assert ":api_key is required" in errors
      assert ":project_id is required" in errors
      assert ":host must be a string, got 42" in errors
      assert "unknown config key :banana" in errors
    end
  end
end
