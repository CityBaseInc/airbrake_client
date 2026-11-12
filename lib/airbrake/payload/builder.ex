defmodule Airbrake.Payload.Builder do
  @moduledoc false

  alias Airbrake.Payload.Backtrace

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

    Map.merge(
      %{environment: config.context_environment(), hostname: config.hostname()},
      Enum.into(Keyword.get(opts, :context) || %{}, %{})
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
    opts |> Keyword.get(:params) |> process_params(get_config(opts))
  end

  def build(:session, opts) do
    config = get_config(opts)

    logger_metadata =
      if config.get(:session) == :include_logger_metadata,
        do: Keyword.get(opts, :logger_metadata, []),
        else: []

    opts_session = Enum.into(Keyword.get(opts, :session) || %{}, %{})
    full_session = logger_metadata |> Enum.into(%{}) |> Map.merge(opts_session)

    # The session can have structs and tuples (such as the assigns of a socket) and sensitive data (such as Logger
    # metadata), so it is processed like the params.
    if full_session == %{},
      do: nil,
      else: process_params(full_session, config)
  end

  @spec filter_environment(nil) :: nil
  def filter_environment(nil) do
    nil
  end

  @spec filter_environment(map(), keyword()) :: map()
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

  defp process_params(params, config) do
    config.payload_processor().process_params(params, filtered_attributes: config.get(:filter_parameters, []))
  end

  defp get_config(opts),
    do: Keyword.get(opts, :config, Airbrake.Config)
end
