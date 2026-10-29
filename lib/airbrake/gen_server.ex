defmodule Airbrake.GenServer do
  @moduledoc """
  Reports to Airbrake when a `GenServer` terminates abnormally.

  Call `report_termination/2` from the `c:GenServer.terminate/2` callback of
  your `GenServer`:

  ```elixir
  defmodule MyServer do
    use GenServer

    # ...

    @impl GenServer
    def terminate(reason, _state) do
      Airbrake.GenServer.report_termination(reason, context: %{component: inspect(__MODULE__)})
      :ok
    end
  end
  ```

  `report_termination/2` reports only when `reason` indicates the process
  terminated abnormally. It does not report a normal exit (`:normal`) or a
  shutdown (`:shutdown` or `{:shutdown, term}`). `component` is the context
  field that Airbrake uses for the module in which the error occurred.

  See `c:GenServer.terminate/2` for more details about when it is called.

  To report the termination of a process without changing its code, use
  `Airbrake.monitor/1` instead.
  """

  # Explains how to replace `use Airbrake.GenServer` during the 3.0 release candidates. Remove it in 3.0.0.
  @doc false
  defmacro __using__(_opts) do
    raise """
    use Airbrake.GenServer is no longer supported. Use GenServer, and call \
    Airbrake.GenServer.report_termination/2 from the terminate/2 callback instead.\
    """
  end

  @doc """
  Reports the termination of a process for the termination `reason` when the
  process terminates abnormally.

  * `:normal`, `:shutdown`, and `{:shutdown, term}` are not reported, and the
    function returns `nil`.
  * A raised exception (`{exception, stacktrace}`) is reported with its
    stacktrace. An Erlang error is converted to an Elixir exception first using
    `Exception.normalize/3`.
  * Any other reason is reported as a `RuntimeError` with the inspected reason
    as its message.

  `options` are the options of `Airbrake.report/2`. The stacktrace of a raised
  exception replaces the `:stacktrace` option. The values in `:context` and
  `:session` are sent to Airbrake without filtering, so do not put secrets or
  personal data in them.
  """
  @doc since: "3.0.0"
  @spec report_termination(term(), Keyword.t()) :: nil | :ok | {:error, ArgumentError}
  def report_termination(reason, options \\ [])
  def report_termination(:normal, _options), do: nil
  def report_termination(:shutdown, _options), do: nil
  def report_termination({:shutdown, _}, _options), do: nil

  def report_termination({exception, []}, options) when is_exception(exception),
    do: Airbrake.report(exception, Keyword.put(options, :stacktrace, []))

  def report_termination({error, stacktrace} = reason, options) when is_list(stacktrace) do
    if stacktrace?(stacktrace) do
      :error
      |> Exception.normalize(error, stacktrace)
      |> Airbrake.report(Keyword.put(options, :stacktrace, stacktrace))
    else
      report_other_reason(reason, options)
    end
  end

  def report_termination(reason, options), do: report_other_reason(reason, options)

  defp stacktrace?([_ | _] = stacktrace), do: Enum.all?(stacktrace, &stacktrace_entry?/1)
  defp stacktrace?(_), do: false

  defp stacktrace_entry?({module, function, arity_or_args, location})
       when is_atom(module) and is_atom(function) and (is_integer(arity_or_args) or is_list(arity_or_args)) and
              is_list(location),
       do: true

  defp stacktrace_entry?({function, arity_or_args, location})
       when is_function(function) and (is_integer(arity_or_args) or is_list(arity_or_args)) and is_list(location),
       do: true

  defp stacktrace_entry?(_), do: false

  defp report_other_reason(reason, options) do
    reason |> inspect() |> RuntimeError.exception() |> Airbrake.report(options)
  end
end
