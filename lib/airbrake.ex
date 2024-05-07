defmodule Airbrake do
  @moduledoc """
  This module provides functions to report any kind of exception to
  [Airbrake](https://airbrake.io/) or [Errbit](http://errbit.com/).

  `Airbrake.report/2` can be used to report directly to Airbrake.io.
  `Airbrake.Plug` and `Airbrake.Channel` can be used to automatically report
  errors from controllers or channels.

  See [README](readme.html) for configuration and usage instructions.
  """

  use Application

  @doc false
  def start(_type \\ :normal, _args \\ []) do
    import Supervisor.Spec, warn: false

    children = [
      Airbrake.Worker
    ]

    opts = [strategy: :one_for_one, name: Airbrake.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @spec report(Exception.t() | [type: String.t(), message: String.t()], Keyword.t()) :: :ok
  def report(exception, options \\ [])

  @doc """
  Send a report to Airbrake about given exception.

  `exception` could be Exception.t or a keywords list with two keys :type & :message

  `options` is a keywords list with following keys:
    * :params - use it to pass request params
    * :context - use it to pass detailed information about the exceptional situation
    * :session - use it to pass info about user session
    * :env - use it to pass environment variables, headers and so on
    * :stacktrace - use it when you would like send something different than System.stacktrace

  This function will always return `:ok` right away and perform the reporting of the given exception in the background.

  ## Examples
  Exceptions can be reported directly:
      Airbrake.report(ArgumentError.exception("oops"))
      #=> :ok
  Often, you'll want to report something you either rescued or caught.

  For rescued exceptions:
      try do
        raise ArgumentError, "oops"
      rescue
        exception ->
          Airbrake.report(exception)
          # You can also reraise the exception here with reraise/2
      end
  For caught exceptions:
      try do
        throw(:oops)
        # or exit(:oops)
      catch
        kind, value ->
          Airbrake.report([type: kind, message: inspect(value)])
      end
  Using custom data:
      Airbrake.report(
        [type: "DebugInfo", message: "Something went wrong"],
        context: %{
          moon_phase: "eclipse"
        })

  """
  defdelegate report(exception, options), to: Airbrake.Worker

  @doc """
  Monitor exceptions in the target process.

  If you don't want system-wide monitoring, but would like to monitor one specific process,
  then you could use `Airbrake.monitor/1`

  Examples:

  With a given PID:
      Airbrake.monitor(pid)
  With a registered process:
      Airbrake.monitor(Registered.Process.Name)
  With `spawn/1` and its counterparts:
      spawn(fn ->
        :timer.sleep(500)
        String.upcase(nil)
      end) |> Airbrake.monitor
  """
  defdelegate monitor(pid_or_reg_name), to: Airbrake.Worker

  @doc """
  Recursively turns structs into plain maps.  Use this to clean up data for an
  Airbrake report.
  """
  defdelegate destruct(value), to: Airbrake.Utils

  @doc """
  Recursively turns tuples into lists.  Use this to clean up data for an
  Airbrake report.
  """
  defdelegate detuple(value), to: Airbrake.Utils
end
