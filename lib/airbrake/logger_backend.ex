defmodule Airbrake.LoggerBackend do
  @moduledoc """
  A `Logger` backend to post an Airbrake notice when the logger gets an error
  message.

  If you are using [`logger_backends`](https://hex.pm/packages/logger_backends),
  you can add `Airbrake.LoggerBackend` as a logger backend. Put this in the
  `start/2` function of a module that implements the `Application` behaviour:

  ```elixir
  LoggerBackends.add({Airbrake.LoggerBackend, :error})
  ```

  For older versions of Elixir (before 1.15), you can configure it in a
  `config/*.exs` file:

  ```elixir
  config :logger,
    backends: [{Airbrake.LoggerBackend, :error}, :console]
  ```
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

  # The exception is the last "** " line, and its backtrace is the frame lines right after it.
  defp parse_error_message(msg) do
    reversed_lines = msg |> to_string() |> String.split("\n") |> Enum.reverse()

    case Enum.split_while(reversed_lines, &(not exception_line?(&1))) do
      {_, []} ->
        :error

      {reversed_after, [exception_line | reversed_before]} ->
        {frames, rest} = reversed_after |> Enum.reverse() |> Enum.split_while(&frame_line?/1)
        stacktrace = Enum.map(frames, &String.trim_leading/1)
        context = parse_context(Enum.reverse(reversed_before) ++ rest)
        {:ok, parse_exception(exception_line), stacktrace, context}
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
