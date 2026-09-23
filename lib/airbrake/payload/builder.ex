defmodule Airbrake.Payload.Builder do
  @moduledoc false

  alias Airbrake.Payload.Backtrace
  alias Airbrake.Utils

  @filtered_value "[FILTERED]"

  @spec build_error(keyword(), Exception.stacktrace()) :: map()
  def build_error(exception, stacktrace) do
    %{
      type: exception[:type],
      message: exception[:message],
      backtrace: Backtrace.from_stacktrace(stacktrace)
    }
  end

  @spec build(:context | :environment | :params | :session, keyword()) :: map() | nil
  def build(:context, opts) do
    config = get_config(opts)

    %{environment: config.context_environment(), hostname: config.hostname()}
    |> Map.merge(opts |> Keyword.get(:context, %{}) |> Enum.into(%{}))
    |> filter_cookies()
    |> filter_map(config.get(:filter_parameters, []))
  end

  def build(:environment, opts) do
    environment =
      Keyword.get_lazy(opts, :environment, fn ->
        Keyword.get(opts, :env)
      end)

    case environment do
      nil -> nil
      env -> env |> Enum.into(%{}) |> filter_environment(opts)
    end
  end

  def build(:params, opts) do
    config = get_config(opts)
    processor = config.payload_processor()
    filter_parameters = config.get(:filter_parameters, [])

    opts
    |> Keyword.get(:params)
    |> processor.process_params(filtered_attributes: filter_parameters)
  end

  def build(:session, opts) do
    config = get_config(opts)

    logger_metadata =
      if config.get(:session) == :include_logger_metadata,
        do: Keyword.get(opts, :logger_metadata, []),
        else: []

    opts_session = opts |> Keyword.get(:session, %{}) |> Enum.into(%{})

    full_session =
      logger_metadata
      |> Enum.into(%{})
      |> Map.merge(opts_session)
      |> filter_map(config.get(:filter_parameters, []))

    if full_session == %{},
      do: nil,
      else: full_session
  end

  @spec filter_environment(nil) :: nil
  def filter_environment(nil) do
    nil
  end

  @spec filter_environment(map(), keyword()) :: map()
  def filter_environment(environment, opts) do
    config = get_config(opts)
    # The cookie header carries the same values as `context.cookies`, so it is always filtered.
    filtered_attributes = Enum.uniq(["cookie" | config.get(:filter_headers, [])])
    processor = config.payload_processor()

    cond do
      Map.has_key?(environment, "headers") ->
        update_headers(environment, "headers", processor, filtered_attributes)

      Map.has_key?(environment, :headers) ->
        update_headers(environment, :headers, processor, filtered_attributes)

      true ->
        environment
    end
  end

  defp update_headers(environment, key, processor, filtered_attributes) do
    Map.update!(
      environment,
      key,
      &processor.process_headers(&1, filtered_attributes: filtered_attributes)
    )
  end

  # Replaces every cookie value in the context with "[FILTERED]", keeping the
  # cookie names. Cookies commonly hold session tokens and other credentials.
  defp filter_cookies(context) do
    Enum.reduce([:cookies, "cookies"], context, fn key, acc ->
      case acc do
        %{^key => cookies} -> Map.put(acc, key, filter_cookie_values(cookies))
        _ -> acc
      end
    end)
  end

  defp filter_cookie_values(nil), do: nil

  defp filter_cookie_values(cookies) when is_map(cookies) and not is_struct(cookies),
    do: Map.new(cookies, fn {name, _value} -> {name, @filtered_value} end)

  defp filter_cookie_values(cookies) when is_list(cookies) do
    Enum.map(cookies, fn
      {name, _value} -> {name, @filtered_value}
      _other -> @filtered_value
    end)
  end

  defp filter_cookie_values(_cookies), do: @filtered_value

  # Applies `filter_parameters` to the values of a map (recursively, via
  # `Airbrake.Utils.filter_key_value/2`) while preserving the top-level keys.
  defp filter_map(map, filtered_attributes) when filtered_attributes in [nil, []], do: map

  defp filter_map(map, filtered_attributes) do
    Map.new(map, fn {k, v} ->
      {_key, filtered_value} = Utils.filter_key_value({k, v}, filtered_attributes)
      {k, filtered_value}
    end)
  end

  defp get_config(opts),
    do: Keyword.get(opts, :config, Airbrake.Config)
end
