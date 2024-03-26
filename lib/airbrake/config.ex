defmodule Airbrake.Config do
  @moduledoc false

  defmodule Behaviour do
    @moduledoc false

    @callback get(atom()) :: any()

    @callback get(atom(), any()) :: any()

    @callback env :: String.t()

    @callback hostname :: String.t()
  end

  @behaviour Airbrake.Config.Behaviour

  # Gets a value from the `:airbrake_client` config.
  @impl Airbrake.Config.Behaviour
  def get(key, default \\ nil) do
    :airbrake_client
    |> Application.get_env(key, default)
    |> resolve()
  end

  # Returns the name of the environment.
  @impl Airbrake.Config.Behaviour
  def env do
    case Application.get_env(:airbrake_client, :environment) do
      nil -> hostname()
      {:system, var} -> System.get_env(var, hostname())
      atom_env when is_atom(atom_env) -> to_string(atom_env)
      str_env when is_binary(str_env) -> str_env
      fun_env when is_function(fun_env) -> fun_env.()
    end
  end

  # Returns a hostname.
  @impl Airbrake.Config.Behaviour
  def hostname do
    System.get_env("HOST") || to_string(elem(:inet.gethostname(), 1))
  end

  defp resolve({:system, key, default}), do: System.get_env(key) || default
  defp resolve({:system, key}), do: System.get_env(key)
  defp resolve(value), do: value
end
