defmodule Airbrake.Config.Validator do
  @moduledoc """
  Validates the `:airbrake_client` application configuration.

  Called during application startup to catch configuration errors early. Returns
  `:ok` or `{:error, reasons}` where `reasons` is a list of human-readable error
  strings.
  """

  @known_keys [
    :api_key,
    :context_environment,
    :environment,
    :filter_headers,
    :filter_parameters,
    :host,
    :ignore,
    :json_encoder,
    :options,
    :payload_processor,
    :private,
    :production_aliases,
    :project_id,
    :session
  ]

  @doc """
  Validates the given config (or the `:airbrake_client` app env by default).

  Returns `:ok` if valid, or `{:error, reasons}` with a list of error strings.
  """
  def validate(config \\ Application.get_all_env(:airbrake_client)) do
    check_deprecations(config)

    errors =
      []
      |> check_unknown_keys(config)
      |> check_required(config)
      |> check_types(config)
      |> check_json_encoder(config)
      |> Enum.reverse()

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp check_unknown_keys(errors, config) do
    config
    |> Keyword.keys()
    |> Enum.reject(&(&1 in @known_keys))
    |> Enum.reduce(errors, fn key, acc ->
      ["unknown config key #{inspect(key)}" | acc]
    end)
  end

  defp check_required(errors, config) do
    errors
    |> require_key(config, :api_key)
    |> require_key(config, :project_id)
  end

  defp require_key(errors, config, key) do
    if Keyword.has_key?(config, key),
      do: errors,
      else: ["#{inspect(key)} is required" | errors]
  end

  defp check_types(errors, config) do
    config
    |> Enum.filter(fn {key, _} -> key in @known_keys end)
    |> Enum.reduce(errors, fn {key, value}, acc ->
      case validate_type(key, value) do
        :ok -> acc
        {:error, message} -> [message | acc]
      end
    end)
  end

  defp validate_type(:api_key, value) when is_binary(value), do: :ok
  defp validate_type(:api_key, {:system, var}) when is_binary(var), do: :ok
  defp validate_type(:api_key, {:system, var, default}) when is_binary(var) and is_binary(default), do: :ok
  defp validate_type(:api_key, value), do: {:error, ":api_key must be a string, got #{inspect(value)}"}

  defp validate_type(:project_id, value) when is_integer(value), do: :ok

  defp validate_type(:project_id, value) when is_binary(value) do
    case Integer.parse(value) do
      {_, ""} -> :ok
      _ -> {:error, ":project_id must be an integer or integer string, got #{inspect(value)}"}
    end
  end

  defp validate_type(:project_id, {:system, var}) when is_binary(var), do: :ok
  defp validate_type(:project_id, {:system, var, default}) when is_binary(var) and is_integer(default), do: :ok

  defp validate_type(:project_id, value),
    do: {:error, ":project_id must be an integer or integer string, got #{inspect(value)}"}

  defp validate_type(:host, value) when is_binary(value), do: :ok
  defp validate_type(:host, {:system, var}) when is_binary(var), do: :ok
  defp validate_type(:host, {:system, var, default}) when is_binary(var) and is_binary(default), do: :ok
  defp validate_type(:host, value), do: {:error, ":host must be a string, got #{inspect(value)}"}

  defp validate_type(:json_encoder, value) when is_atom(value), do: :ok
  defp validate_type(:json_encoder, value), do: {:error, ":json_encoder must be a module, got #{inspect(value)}"}

  defp validate_type(:filter_parameters, value) when is_list(value) do
    if Enum.all?(value, &is_binary/1),
      do: :ok,
      else: {:error, ":filter_parameters must be a list of strings"}
  end

  defp validate_type(:filter_parameters, value),
    do: {:error, ":filter_parameters must be a list of strings, got #{inspect(value)}"}

  defp validate_type(:filter_headers, value) when is_list(value) do
    if Enum.all?(value, &is_binary/1),
      do: :ok,
      else: {:error, ":filter_headers must be a list of strings"}
  end

  defp validate_type(:filter_headers, value),
    do: {:error, ":filter_headers must be a list of strings, got #{inspect(value)}"}

  defp validate_type(:production_aliases, value) when is_list(value) do
    if Enum.all?(value, &is_binary/1),
      do: :ok,
      else: {:error, ":production_aliases must be a list of strings"}
  end

  defp validate_type(:production_aliases, value),
    do: {:error, ":production_aliases must be a list of strings, got #{inspect(value)}"}

  defp validate_type(:session, :include_logger_metadata), do: :ok
  defp validate_type(:session, nil), do: :ok

  defp validate_type(:session, value),
    do: {:error, ":session must be :include_logger_metadata or nil, got #{inspect(value)}"}

  defp validate_type(:ignore, nil), do: :ok
  defp validate_type(:ignore, :all), do: :ok
  defp validate_type(:ignore, %MapSet{}), do: :ok
  defp validate_type(:ignore, fun) when is_function(fun, 2), do: :ok

  defp validate_type(:ignore, value),
    do: {:error, ":ignore must be nil, :all, a MapSet, or a 2-arity function, got #{inspect(value)}"}

  defp validate_type(:options, {mod, fun, 1}) when is_atom(mod) and is_atom(fun), do: :ok

  defp validate_type(:options, value) when is_list(value) do
    if Keyword.keyword?(value),
      do: :ok,
      else: {:error, ":options must be a keyword list or {mod, fun, 1} tuple"}
  end

  defp validate_type(:options, value),
    do: {:error, ":options must be a keyword list or {mod, fun, 1} tuple, got #{inspect(value)}"}

  defp validate_type(:context_environment, value) when is_binary(value), do: :ok
  defp validate_type(:context_environment, value) when is_atom(value), do: :ok
  defp validate_type(:context_environment, {:system, var}) when is_binary(var), do: :ok
  defp validate_type(:context_environment, fun) when is_function(fun, 0), do: :ok

  defp validate_type(:context_environment, value),
    do:
      {:error,
       ":context_environment must be a string, atom, {:system, var}, or 0-arity function, got #{inspect(value)}"}

  defp validate_type(:environment, value) when is_binary(value), do: :ok
  defp validate_type(:environment, value) when is_atom(value), do: :ok
  defp validate_type(:environment, {:system, var}) when is_binary(var), do: :ok
  defp validate_type(:environment, fun) when is_function(fun, 0), do: :ok

  defp validate_type(:environment, value),
    do: {:error, ":environment must be a string, atom, {:system, var}, or 0-arity function, got #{inspect(value)}"}

  @payload_processor_callbacks [{:process_params, 2}, {:process_headers, 2}, {:encode!, 1}]

  defp validate_type(:payload_processor, value) when is_atom(value) do
    if Code.ensure_loaded?(value),
      do: check_payload_processor_callbacks(value),
      else: {:error, ":payload_processor module #{inspect(value)} is not available"}
  end

  defp validate_type(:payload_processor, value),
    do: {:error, ":payload_processor must be a module, got #{inspect(value)}"}

  defp validate_type(:private, value) when is_list(value), do: :ok

  defp validate_type(:private, value),
    do: {:error, ":private must be a keyword list, got #{inspect(value)}"}

  defp check_payload_processor_callbacks(module) do
    missing =
      Enum.reject(@payload_processor_callbacks, fn {fun, arity} ->
        function_exported?(module, fun, arity)
      end)

    case missing do
      [] ->
        :ok

      missing ->
        formatted = Enum.map_join(missing, ", ", fn {f, a} -> "#{f}/#{a}" end)
        {:error, ":payload_processor module #{inspect(module)} is missing callbacks: #{formatted}"}
    end
  end

  defp check_deprecations(config) do
    if Keyword.has_key?(config, :json_encoder) do
      IO.warn("airbrake_client: :json_encoder is deprecated, use :payload_processor instead")
      :ok
    end

    if Keyword.has_key?(config, :environment) do
      IO.warn("airbrake_client: :environment is deprecated, use :context_environment instead")
      :ok
    end
  end

  defp check_json_encoder(errors, config) do
    has_payload_processor = Keyword.has_key?(config, :payload_processor)
    has_json_encoder = Keyword.has_key?(config, :json_encoder)

    cond do
      has_payload_processor and has_json_encoder ->
        processor = Keyword.fetch!(config, :payload_processor)
        IO.warn("airbrake_client: :json_encoder is ignored because :payload_processor is set to #{inspect(processor)}")
        errors

      has_payload_processor ->
        errors

      true ->
        encoder = Keyword.get(config, :json_encoder, Poison)

        if is_atom(encoder) and not Code.ensure_loaded?(encoder) do
          ["JSON encoder #{inspect(encoder)} is not available" | errors]
        else
          errors
        end
    end
  end
end
