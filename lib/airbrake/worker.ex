defmodule Airbrake.Worker do
  @moduledoc false
  use GenServer

  alias Airbrake.Config
  alias Airbrake.Notice

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            refs: %{optional(reference()) => pid() | atom()},
            last_exception: {keyword(), keyword()} | nil
          }

    defstruct refs: %{}, last_exception: nil
  end

  @name __MODULE__

  @doc """
  Send a report to Airbrake.
  """
  @spec report(Exception.t() | [type: String.t(), message: String.t()], Keyword.t()) :: :ok | {:error, ArgumentError}
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

  @spec remember(Exception.t() | [type: String.t(), message: String.t()], Keyword.t()) :: :ok | {:error, ArgumentError}
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

  @spec monitor(pid() | atom()) :: :ok | {:error, ArgumentError}
  def monitor(pid_or_reg_name) when is_pid(pid_or_reg_name) or is_atom(pid_or_reg_name) do
    GenServer.cast(@name, {:monitor, pid_or_reg_name})
  end

  def monitor(_) do
    {:error, ArgumentError}
  end

  @spec start_link() :: GenServer.on_start()
  def start_link do
    start_link([])
  end

  @spec start_link(list()) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(@name, %State{}, name: @name)
  end

  @spec exception_info(Exception.t()) :: [type: String.t(), message: String.t()]
  def exception_info(exception) do
    [type: inspect(exception.__struct__), message: Exception.message(exception)]
  end

  @spec init(State.t()) :: {:ok, State.t()}
  def init(state) do
    {:ok, state}
  end

  @spec handle_cast(term(), State.t()) :: {:noreply, State.t()}
  def handle_cast({:report, exception, stacktrace, options}, %{last_exception: {remembered, details}} = state) do
    if same_exception?(exception, remembered) do
      enhanced_options =
        Enum.reduce([:context, :params, :session, :env], options, fn key, enhanced_options ->
          Keyword.put(enhanced_options, key, merge_detail(options[key], details[key]))
        end)

      Notice.post_notice(exception, stacktrace, enhanced_options)
      {:noreply, Map.put(state, :last_exception, nil)}
    else
      Notice.post_notice(exception, stacktrace, options)
      {:noreply, state}
    end
  end

  def handle_cast({:report, exception, stacktrace, options}, state) do
    Notice.post_notice(exception, stacktrace, options)
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

  @spec handle_info(term(), State.t()) :: {:noreply, State.t()}
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {pname, refs} = Map.pop(state.refs, ref)
    Airbrake.GenServer.report_termination(reason, monitor_options(pname, pid))
    {:noreply, Map.put(state, :refs, refs)}
  end

  # Without this clause, an unexpected message crashes the worker.
  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp get_stacktrace do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)
    stacktrace
  end

  defp maybe_add_logger_metadata(opts) do
    if Config.get(:session) == :include_logger_metadata,
      do: Keyword.put(opts, :logger_metadata, Logger.metadata()),
      else: opts
  end

  # Airbrake.LoggerBackend reports only the first line of a message with more than one line.
  defp same_exception?(exception, exception), do: true

  defp same_exception?([type: type, message: message], type: type, message: remembered_message)
       when is_binary(remembered_message),
       do: message == remembered_message |> String.split("\n", parts: 2) |> hd()

  defp same_exception?(_exception, _remembered), do: false

  # The remembered detail wins. An option can be a keyword list, and params can be any term.
  defp merge_detail(option, detail) do
    case {as_map(option || %{}), as_map(detail || %{})} do
      {%{} = option, %{} = detail} -> Map.merge(option, detail)
      {option, detail} when detail == %{} -> option
      {_option, detail} -> detail
    end
  end

  defp as_map(value) when is_list(value), do: if(Keyword.keyword?(value), do: Map.new(value), else: value)
  defp as_map(value), do: value

  # So that Airbrake can group properly:
  # * A monitored name is the context.component since it remains constant.
  # * The pid is different for each process, so it goes in the session.
  defp monitor_options(pid, pid), do: [session: %{process: inspect(pid)}]
  defp monitor_options(name, pid), do: [context: %{component: inspect(name)}, session: %{process: inspect(pid)}]

  @deprecated "Use Airbrake.Config.get/2 instead."
  @spec get_env(atom(), term()) :: term()
  def get_env(key, default \\ nil),
    do: Config.get(key, default)
end
