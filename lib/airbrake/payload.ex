defmodule Airbrake.Payload do
  @moduledoc false

  alias Airbrake.Config

  @notifier_info %{
    name: "Airbrake Client",
    version: Airbrake.Mixfile.project()[:version],
    url: Airbrake.Mixfile.project()[:package][:links][:github]
  }

  if Code.ensure_loaded?(Jason.Encoder),
    do: @derive(Jason.Encoder)

  defstruct apiKey: nil,
            context: nil,
            environment: nil,
            errors: nil,
            notifier: @notifier_info,
            params: nil,
            session: nil

  alias Airbrake.Payload.Backtrace
  alias Airbrake.Utils

  def new(exception, stacktrace, options \\ [])

  def new(%{__exception__: true} = exception, stacktrace, options) do
    new(Airbrake.Worker.exception_info(exception), stacktrace, options)
  end

  def new(exception, stacktrace, options) when is_list(exception) do
    %__MODULE__{
      errors: [build_error(exception, stacktrace)],
      context: build(:context, options),
      environment: build(:environment, options),
      params: build(:params, options),
      session: build(:session, options)
    }
  end

  defp build_error(exception, stacktrace) do
    %{
      type: exception[:type],
      message: exception[:message],
      backtrace: Backtrace.from_stacktrace(stacktrace)
    }
  end

  defp build(:context, options) do
    Map.merge(
      %{environment: Config.env(), hostname: Config.hostname()},
      Keyword.get(options, :context, %{})
    )
  end

  defp build(:environment, options) do
    options |> Keyword.get(:env) |> filter_environment()
  end

  defp build(:params, options) do
    options |> Keyword.get(:params) |> filter_parameters()
  end

  defp build(key, options) do
    Keyword.get(options, key)
  end

  defp filter_parameters(params), do: filter(params, :filter_parameters)

  defp filter_environment(nil) do
    nil
  end

  defp filter_environment(env) do
    if Map.has_key?(env, "headers"),
      do: Map.update!(env, "headers", &filter(&1, :filter_headers)),
      else: env
  end

  defp filter(map, config_key) do
    Utils.filter(map, Config.get(config_key))
  end
end
