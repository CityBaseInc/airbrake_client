defmodule Airbrake.Payload.Builder do
  @moduledoc false

  alias Airbrake.Payload.Backtrace

  def build_error(exception, stacktrace) do
    %{
      type: exception[:type],
      message: exception[:message],
      backtrace: Backtrace.from_stacktrace(stacktrace)
    }
  end

  def build(:context, opts) do
    config = get_config(opts)

    Map.merge(
      %{environment: config.context_environment(), hostname: config.hostname()},
      opts |> Keyword.get(:context, %{}) |> Enum.into(%{})
    )
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
    full_session = logger_metadata |> Enum.into(%{}) |> Map.merge(opts_session)

    if full_session == %{},
      do: nil,
      else: full_session
  end

  def filter_environment(nil) do
    nil
  end

  def filter_environment(environment, opts) do
    config = get_config(opts)
    filtered_attributes = config.get(:filter_headers, [])
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

  defp get_config(opts),
    do: Keyword.get(opts, :config, Airbrake.Config)
end
