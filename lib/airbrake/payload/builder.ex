defmodule Airbrake.Payload.Builder do
  @moduledoc false

  alias Airbrake.Payload.Backtrace
  alias Airbrake.Utils

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
    case Keyword.get(opts, :params) do
      nil -> nil
      params -> params |> Enum.into(%{}) |> filter_parameters(opts)
    end
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

  def filter_parameters(params, opts) do
    filter_parameters = get_config(opts).get(:filter_parameters, [])

    Utils.filter(params, filter_parameters)
  end

  def filter_environment(nil) do
    nil
  end

  def filter_environment(environment, opts) do
    filter_headers = get_config(opts).get(:filter_headers, [])

    cond do
      Map.has_key?(environment, "headers") ->
        Map.update!(environment, "headers", &Utils.filter(&1, filter_headers))

      Map.has_key?(environment, :headers) ->
        Map.update!(environment, :headers, &Utils.filter(&1, filter_headers))

      true ->
        environment
    end
  end

  defp get_config(opts),
    do: Keyword.get(opts, :config, Airbrake.Config)
end
