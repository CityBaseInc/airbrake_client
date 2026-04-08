defmodule Airbrake.Payload do
  @moduledoc false

  alias Airbrake.Payload.Builder

  @type t :: %__MODULE__{
          apiKey: String.t() | nil,
          context: map() | nil,
          environment: map() | nil,
          errors: [map()] | nil,
          notifier: map() | nil,
          params: map() | nil,
          session: map() | nil
        }

  @notifier_info %{
    name: "Airbrake Client",
    version: Airbrake.Mixfile.project()[:version],
    url: Airbrake.Mixfile.project()[:package][:links][:github]
  }

  defstruct apiKey: nil,
            context: nil,
            environment: nil,
            errors: nil,
            notifier: @notifier_info,
            params: nil,
            session: nil

  @spec new(Exception.t() | [type: String.t(), message: String.t()], Exception.stacktrace(), keyword()) :: t()
  def new(exception, stacktrace, opts \\ [])

  def new(%{__exception__: true} = exception, stacktrace, opts) do
    new(Airbrake.Worker.exception_info(exception), stacktrace, opts)
  end

  def new(exception, stacktrace, opts) when is_list(exception) do
    %__MODULE__{
      errors: [Builder.build_error(exception, stacktrace)],
      context: Builder.build(:context, opts),
      environment: Builder.build(:environment, opts),
      params: Builder.build(:params, opts),
      session: Builder.build(:session, opts)
    }
  end
end
