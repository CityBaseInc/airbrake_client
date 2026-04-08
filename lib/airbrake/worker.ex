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

  @spec monitor(pid() | atom()) :: :ok
  def monitor(pid_or_reg_name) do
    GenServer.cast(@name, {:monitor, pid_or_reg_name})
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
  def handle_cast({:report, exception, stacktrace, options}, %{last_exception: {exception, details}} = state) do
    enhanced_options =
      Enum.reduce([:context, :params, :session, :env], options, fn key, enhanced_options ->
        Keyword.put(enhanced_options, key, Map.merge(options[key] || %{}, details[key] || %{}))
      end)

    Notice.post_notice(exception, stacktrace, enhanced_options)
    {:noreply, Map.put(state, :last_exception, nil)}
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
    Airbrake.GenServer.handle_terminate(reason, %{process_name: process_name(pname, pid)})
    {:noreply, Map.put(state, :refs, refs)}
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

  defp process_name(pid, pid), do: "Process [#{inspect(pid)}]"
  defp process_name(pname, pid), do: "#{inspect(pname)} [#{inspect(pid)}]"

  @deprecated "Use Airbrake.Config.get/2 instead."
  @spec get_env(atom(), term()) :: term()
  def get_env(key, default \\ nil),
    do: Config.get(key, default)
end
