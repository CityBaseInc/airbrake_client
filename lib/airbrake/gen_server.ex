defmodule Airbrake.GenServer do
  @moduledoc """
  This module provides the ability to monitor workers of a `GenServer`.

  Use `Airbrake.GenServer` instead of `GenServer`. A notice will be posted if
  the process terminates abnormally.

  ## Example

  ```elixir
  defmodule MyServer do
    use Airbrake.GenServer

    # ...
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      use GenServer
      import Airbrake.GenServer

      def terminate(reason, state) do
        handle_terminate(reason, %{process_name: __MODULE__, state: inspect(state)})
        :ok
      end
    end
  end

  @doc """
  Implements a set of reporting rules based on process termination reason.
  Could be overridden if you want to.
  """
  @spec handle_terminate(term(), map()) :: nil | :ok | {:error, ArgumentError}
  def handle_terminate(reason, context)
  def handle_terminate(:normal, _), do: nil
  def handle_terminate(:shutdown, _), do: nil
  def handle_terminate({:shutdown, _}, _), do: nil

  def handle_terminate({err_type, stacktrace}, context) when is_atom(err_type) and is_list(stacktrace) do
    ErlangError.normalize(err_type, stacktrace) |> Airbrake.report(context: context)
  end

  def handle_terminate(reason, context) do
    RuntimeError.exception(inspect(reason)) |> Airbrake.report(context: context)
  end

  defoverridable handle_terminate: 2
end
