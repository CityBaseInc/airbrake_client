defmodule Airbrake.LoggerBackend do
  @moduledoc """
  A `Logger` backend that posts an Airbrake notice when an error log message
  contains a formatted exception.

  ## Setup

  The `Logger` backends API is in the
  [`logger_backends`](https://hex.pm/packages/logger_backends) package. Add it
  to your dependencies:

  ```elixir
  {:logger_backends, "~> 1.0"}
  ```

  Then add the backend in the `start/2` callback of your application:

  ```elixir
  LoggerBackends.add({Airbrake.LoggerBackend, :error})
  ```

  You must add the backend as a `{module, id}` tuple. The id (`:error` here)
  only names the backend. It does not set a log level.

  For backwards compatibility, Elixir also lets you add the backend in a
  `config/*.exs` file without `logger_backends`:

  ```elixir
  config :logger,
    backends: [{Airbrake.LoggerBackend, :error}, :console]
  ```

  Keep `:console` in the list. If `:backends` does not include `:console`,
  Elixir turns off its default console logging.

  ## What the backend reports

  The backend handles only `:error` events from the local node. Logger backends
  receive `:critical`, `:alert`, and `:emergency` events as `:error` events, so
  the backend handles those too.

  The backend reports an event only if a line of its message starts with `** `.
  Elixir uses this format for exceptions, for example in `Exception.format/3`
  and in the crash reports for GenServers and Tasks. The backend does not report
  other error messages, such as `Logger.error("payment failed")`.

  The backend builds the notice from the text of the message, not from the
  original exception:

    * **Error type and message.** The backend gets these from the
      `** (Type) message` line. If there is more than one such line, the
      backend uses the last one. If the line has no `(Type)`, the type is
      `"RuntimeError"` and the message is the rest of the line. If the
      exception message has more than one line, only its first line is the
      error message, and the backend ignores the other lines.

    * **Backtrace.** The indented stacktrace lines after the exception message
      are the backtrace, for example
      `(my_app 0.1.0) lib/my_app/worker.ex:12: MyApp.Worker.run/1` or
      `lib/my_app/worker.ex:12: MyApp.Worker.run/1`. The backend ignores other
      stacktrace lines. For example, a GenServer crash report also has the
      stacktrace of the client that called the GenServer, and the backtrace
      does not include it.

    * **Context.** Each line of the form `Key: value` adds the lowercased key
      and its value to the context. A GenServer crash report adds
      `"last message"` and `"state"`, and a Task crash report adds
      `"function"` and `"args"`. The first line that is not `Key: value` is
      the `"title"`. The context also has the `environment` and `hostname`,
      as in every notice.

  The backend does not send the `Logger` metadata of the event. Logger can
  truncate a long message before the backend gets it (see the `:truncate`
  option of `Logger`), and then the end of the backtrace is lost.

  > #### Sensitive data {: .warning}
  >
  > The backend sends the exception message and the context values as they
  > appear in the log message. The `:filter_parameters` and `:filter_headers`
  > options do not apply to them. A GenServer crash report includes the last
  > message and the full state of the GenServer, which can include secrets or
  > personal data.
  """

  @behaviour :gen_event

  @spec init({module(), atom()}) :: {:ok, nil}
  def init({__MODULE__, _name}) do
    {:ok, nil}
  end

  @spec handle_call(term(), nil) :: {:ok, :ok, nil}
  def handle_call(_, state) do
    {:ok, :ok, state}
  end

  @spec handle_event(term(), nil) :: {:ok, nil}
  def handle_event({_level, gl, _event}, state)
      when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({:error, _, {Logger, msg, _ts, _metadata}}, state) do
    case parse_error_message(msg) do
      {:ok, exception, stacktrace, context} -> Airbrake.report(exception, stacktrace: stacktrace, context: context)
      :error -> :ok
    end

    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  # The exception is the last "** " line, and its backtrace is the frame lines after the rest of its message.
  defp parse_error_message(msg) do
    reversed_lines = msg |> to_string() |> String.split("\n") |> Enum.reverse()

    case Enum.split_while(reversed_lines, &(not exception_line?(&1))) do
      {_, []} ->
        :error

      {reversed_after, [exception_line | reversed_before]} ->
        {frames, rest} = reversed_after |> Enum.reverse() |> split_backtrace()
        stacktrace = Enum.map(frames, &String.trim_leading/1)
        context = parse_context(Enum.reverse(reversed_before) ++ rest)
        {:ok, parse_exception(exception_line), stacktrace, context}
    end
  end

  # Without frames, the lines after the exception are context, not the rest of its message.
  defp split_backtrace(lines) do
    case Enum.split_while(lines, &(not frame_line?(&1))) do
      {_message_lines, [_ | _] = frames_and_rest} -> Enum.split_while(frames_and_rest, &frame_line?/1)
      {_, []} -> {[], lines}
    end
  end

  defp exception_line?(line), do: String.starts_with?(String.trim_leading(line), "** ")

  # Matches "(app vsn) file:line: function", "(app vsn) function", and "file:line: function".
  defp frame_line?("    " <> line), do: Regex.match?(~r/\A(\(|\S+:\d+: )/, line)
  defp frame_line?(_line), do: false

  defp parse_exception(line) do
    "** " <> err_msg = String.trim_leading(line)

    case Regex.run(~r/\((.*?)\)\s*(.*?)\z/, err_msg) do
      [_, type, message] -> [type: type, message: message]
      _ -> [type: "RuntimeError", message: err_msg]
    end
  end

  defp parse_context(lines) do
    lines
    |> Enum.reject(&(frame_line?(&1) or String.trim(&1) == ""))
    |> Enum.reduce(%{}, fn line, context ->
      case line |> String.trim_leading() |> String.split(": ", parts: 2) do
        [key, value] -> Map.put_new(context, String.downcase(key), value)
        [title] -> Map.put_new(context, "title", title)
      end
    end)
  end
end
