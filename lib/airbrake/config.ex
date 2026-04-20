defmodule Airbrake.Config do
  @moduledoc false

  @behaviour Airbrake.Config.Behaviour

  defmodule Behaviour do
    @moduledoc false

    @callback get(atom()) :: any()

    @callback get(atom(), any()) :: any()

    @callback context_environment :: String.t()

    @callback hostname :: String.t()

    @callback payload_processor :: module()

    @callback project_id :: integer()
  end

  @doc """
  Gets a value from the `:airbrake_client` config.

  Resolves `{:system, var}` and `{:system, var, default}` tuples to their
  environment variable values.
  """
  @impl Airbrake.Config.Behaviour
  @spec get(atom(), term()) :: term()
  def get(key, default \\ nil) do
    :airbrake_client
    |> Application.get_env(key, default)
    |> resolve()
  end

  @doc """
  Returns the name of the environment.

  Checks `:context_environment`, then `:environment`, then falls back to
  `hostname/0`. Values in `:production_aliases` are mapped to `"production"`.
  """
  @impl Airbrake.Config.Behaviour
  @spec context_environment(module()) :: String.t()
  def context_environment(config \\ __MODULE__) do
    config_context_environment =
      case config.get(:context_environment) || config.get(:environment) do
        nil -> hostname()
        {:system, var} -> System.get_env(var, hostname())
        atom_env when is_atom(atom_env) -> to_string(atom_env)
        str_env when is_binary(str_env) -> str_env
        fun_env when is_function(fun_env) -> fun_env.()
      end

    if config_context_environment in config.get(:production_aliases, []),
      do: "production",
      else: config_context_environment
  end

  @doc """
  Returns the configured `Airbrake.PayloadProcessor` module.

  When not set, falls back to `:json_encoder`, mapping it to the corresponding
  module. If neither `:payload_processor` nor `:json_encoder` are set, defaults
  to `Airbrake.PoisonPayloadProcessor`.
  """
  @impl Airbrake.Config.Behaviour
  @spec payload_processor(module()) :: module()
  def payload_processor(config \\ __MODULE__) do
    case config.get(:payload_processor) do
      nil -> payload_processor_from_json_encoder(config)
      mod when is_atom(mod) -> mod
    end
  end

  @doc """
  Returns the project ID as an integer.

  Converts a string value to an integer if necessary.
  """
  @impl Airbrake.Config.Behaviour
  @spec project_id(module()) :: integer()
  def project_id(config \\ __MODULE__) do
    case config.get(:project_id) do
      value when is_binary(value) -> String.to_integer(value)
      value -> value
    end
  end

  defp payload_processor_from_json_encoder(config) do
    case config.get(:json_encoder) do
      Jason -> Airbrake.JasonPayloadProcessor
      :json -> Airbrake.JsonPayloadProcessor
      _ -> Airbrake.PoisonPayloadProcessor
    end
  end

  @doc """
  Returns a hostname.

  Uses the `HOST` environment variable, falling back to the system hostname.
  """
  @impl Airbrake.Config.Behaviour
  @spec hostname() :: String.t()
  def hostname do
    System.get_env("HOST") || to_string(elem(:inet.gethostname(), 1))
  end

  defp resolve({:system, key, default}), do: System.get_env(key) || default
  defp resolve({:system, key}), do: System.get_env(key)
  defp resolve(value), do: value
end
