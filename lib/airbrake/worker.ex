defmodule Airbrake.Worker do
  @moduledoc false
  use GenServer

  require Airbrake.JSONEncoder

  alias Airbrake.{Config, Payload}

  defmodule State do
    @moduledoc false
    defstruct refs: %{}, last_exception: nil
  end

  @name __MODULE__
  @request_headers [{"Content-Type", "application/json"}]
  @default_host "https://api.airbrake.io"
  @http_adapter :airbrake_client
                |> Application.compile_env(:private, [])
                |> Keyword.get(:http_adapter, HTTPoison)

  @doc """
  Send a report to Airbrake.
  """
  @spec report(Exception.t() | [type: String.t(), message: String.t()], Keyword.t()) :: :ok
  def report(exception, options \\ [])

  def report(%{__exception__: true} = exception, options) when is_list(options) do
    report(exception_info(exception), options)
  end

  def report([type: _, message: _] = exception, options) when is_list(options) do
    stacktrace = options[:stacktrace] || get_stacktrace()

    options =
      options
      |> Keyword.delete(:stacktrace)
      |> maybe_add_logger_metadata()

    GenServer.cast(@name, {:report, exception, stacktrace, options})
  end

  def report(_, _) do
    {:error, ArgumentError}
  end

  @spec remember(Exception.t() | [type: String.t(), message: String.t()], Keyword.t()) :: :ok
  def remember(exception, options \\ [])

  def remember(%{__exception__: true} = exception, options) when is_list(options) do
    remember(exception_info(exception), options)
  end

  def remember([type: _, message: _] = exception, options) when is_list(options) do
    GenServer.cast(@name, {:remember, exception, options})
  end

  def remember(_, _) do
    {:error, ArgumentError}
  end

  def monitor(pid_or_reg_name) do
    GenServer.cast(@name, {:monitor, pid_or_reg_name})
  end

  def start_link do
    start_link([])
  end

  def start_link([]) do
    GenServer.start_link(@name, %State{}, name: @name)
  end

  def exception_info(exception) do
    [type: inspect(exception.__struct__), message: Exception.message(exception)]
  end

  def init(state) do
    json_encoder = Airbrake.JSONEncoder.encoder()

    if Code.ensure_loaded?(json_encoder) do
      {:ok, state}
    else
      {:stop, "JSON encoder #{inspect(json_encoder)} is missing"}
    end
  end

  def handle_cast({:report, exception, stacktrace, options}, %{last_exception: {exception, details}} = state) do
    enhanced_options =
      Enum.reduce([:context, :params, :session, :env], options, fn key, enhanced_options ->
        Keyword.put(enhanced_options, key, Map.merge(options[key] || %{}, details[key] || %{}))
      end)

    send_report(exception, stacktrace, enhanced_options)
    {:noreply, Map.put(state, :last_exception, nil)}
  end

  def handle_cast({:report, exception, stacktrace, options}, state) do
    send_report(exception, stacktrace, options)
    {:noreply, state}
  end

  def handle_cast({:remember, exception, options}, state) do
    state = Map.put(state, :last_exception, {exception, options})
    {:noreply, state}
  end

  def handle_cast({:monitor, pid_or_reg_name}, state) do
    ref = Process.monitor(pid_or_reg_name)
    state = Map.put(state, :refs, Map.put(state.refs, ref, pid_or_reg_name))
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {pname, refs} = Map.pop(state.refs, ref)
    Airbrake.GenServer.handle_terminate(reason, %{process_name: process_name(pname, pid)})
    {:noreply, Map.put(state, :refs, refs)}
  end

  defp send_report(exception, stacktrace, options) do
    unless ignore?(exception) do
      enhanced_options = build_options(options)
      payload = Payload.new(exception, stacktrace, enhanced_options)
      json_payload = encode_payload(payload)
      @http_adapter.post(notify_url(), json_payload, @request_headers)
    end
  end

  defp build_options(current_options) do
    case Config.get(:options) do
      {mod, fun, 1} ->
        apply(mod, fun, [current_options])

      shared_options when is_list(shared_options) ->
        Keyword.merge(shared_options, current_options)

      _ ->
        current_options
    end
  end

  defp encode_payload(%Payload{} = payload) do
    Airbrake.JSONEncoder.encode!(payload)
  rescue
    UndefinedFunctionError ->
      IO.warn("JSON encoder does not have an encode!/1 function")
      "{\"errors\":[{\"message\":\"JSON encoder does not have an encode!/1 function\"}]}"
  end

  defp get_stacktrace do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
    stacktrace
  end

  defp ignore?(type: type, message: message) do
    ignore?(Config.get(:ignore), type, message)
  end

  defp ignore?(nil, _type, _message), do: false
  defp ignore?(:all, _type, _message), do: true
  defp ignore?(fun, type, message) when is_function(fun), do: fun.(type, message)
  defp ignore?(types, type, _message), do: MapSet.member?(types, type)

  defp maybe_add_logger_metadata(opts) do
    if Config.get(:session) == :include_logger_metadata,
      do: Keyword.put(opts, :logger_metadata, Logger.metadata()),
      else: opts
  end

  defp process_name(pid, pid), do: "Process [#{inspect(pid)}]"
  defp process_name(pname, pid), do: "#{inspect(pname)} [#{inspect(pid)}]"

  defp notify_url do
    Path.join([
      Config.get(:host, @default_host),
      "api/v3/projects",
      :project_id |> Config.get() |> to_string(),
      "notices?key=#{Config.get(:api_key)}"
    ])
  end

  @deprecated "Use Airbrake.Config.get/2 instead."
  def get_env(key, default \\ nil),
    do: Config.get(key, default)
end
