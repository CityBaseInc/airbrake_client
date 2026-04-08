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

  alias Airbrake.Config.Validator

  @doc false
  def start(_type \\ :normal, _args \\ []) do
    with :ok <- Validator.validate() do
      children = [
        Airbrake.Worker
      ]

      opts = [strategy: :one_for_one, name: Airbrake.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end

  @spec report(Exception.t() | [type: String.t(), message: String.t()], Keyword.t()) :: :ok | {:error, ArgumentError}
  def report(exception, options \\ [])

  @doc """
  Posts a notice to Airbrake about one exception.

  `exception` could be Exception.t or a keywords list with two keys :type & :message

  `options` is a keywords list with following options that related to the fields
  of an [Airbrake
  notice](https://docs.airbrake.io/docs/devops-tools/api/#create-notice-v3):
    * :params - use it to pass request params for `notice.errors[0].params`.
    * :context - use it to pass context information for `notice.context`.
    * :session - use it to pass information about the user session for
      `notice.session`.
    * :env - use it to pass environment variables and HTTP headers for
      `notice.environment`.
    * :stacktrace - use it when you would like your own stack trace for
      `notice.errors[0].backtrace`

  This function will always return `:ok` right away and perform the reporting of
  the given exception in the background.

  ## JSON Encoding

  Be very careful of the values that you add to a notice. `jason` and `poison`
  do not encode everything out of the box, so keep yourself to maps, lists, and
  simple scalars for all values except for `:params`.

  The value of `:params` is processed by
  `c:Airbrake.PayloadProcessor.process_params/2` which should do it's best to
  make an Elixir term into something encodable. The default implementations turn
  tuples, structs and keyword lists into encodable terms (e.g., a struct into a
  map). It also filters keys in maps and associative lists for sensitive data.
  See the documentation for `c:Airbrake.PayloadProcessor.process_params/2`, the
  documentation for `Airbrake.PayloadProcessor`, and ["Payload
  Processor"](payload_processor.html) for more information.

  ## Examples

  In each example, you can add any of the options listed above as a second
  argument.

  Exceptions can be reported directly:

  ```elixir
  Airbrake.report(ArgumentError.exception("oops"))
  ```

  Often, you'll want to report something you either rescued or caught.

  For rescued exceptions:

  ```elixir
  try do
    # might raise an error...
  rescue
    exception -> Airbrake.report(exception)
  end
  ```

  For caught exceptions:

  ```elixir
  try do
    # might throw an error...
  catch
    kind, value -> Airbrake.report([type: kind, message: inspect(value)])
  end
  ```

  Building a notice:

  ```elixir
  Airbrake.report([type: "DebugInfo", message: "Something went wrong"])
  ```
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
  @deprecated "Use Airbrake.Utils.destruct/1."
  defdelegate destruct(value), to: Airbrake.Utils

  @doc """
  Recursively turns tuples into lists.  Use this to clean up data for an
  Airbrake report.
  """
  @deprecated "Use Airbrake.Utils.detuple/1."
  defdelegate detuple(value), to: Airbrake.Utils
end
