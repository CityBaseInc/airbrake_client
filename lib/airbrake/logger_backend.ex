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
    try do
      err_info = parse_error_message(msg)

      Airbrake.report(err_info[:exception],
        stacktrace: err_info[:stacktrace] || [],
        context: err_info[:context]
      )
    rescue
      # credo:disable-for-next-line
      exception -> IO.inspect(exception)
    end

    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  defp parse_error_message(msg) do
    msg
    |> to_string
    |> String.split("\n")
    |> Enum.reverse()
    |> Enum.reduce(%{stacktrace: [], context: %{}}, &parse_line/2)
  end

  defp parse_line("    " <> line, res), do: parse_line(line, res)

  defp parse_line("** " <> err_msg, res) do
    case Regex.run(~r/\((.*?)\)\s*(.*?)\z/, err_msg) do
      [_, type, message] ->
        Map.put_new(res, :exception, type: type, message: message)

      _ ->
        Map.put_new(res, :exception, type: "RuntimeError", message: err_msg)
    end
  end

  defp parse_line("(" <> _ = st_line, res) do
    Map.put(res, :stacktrace, [st_line | Map.get(res, :stacktrace, [])])
  end

  defp parse_line(line, res) do
    case String.split(line, ": ", parts: 2) do
      [key, value] ->
        key = key |> String.downcase() |> String.to_atom()
        put_in(res, [:context, key], value)

      [value] ->
        put_in(res, [:context, :title], value)
    end
  end
end
