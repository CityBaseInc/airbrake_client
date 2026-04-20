defmodule Airbrake.Channel do
  @moduledoc """
  Reports errors encountered on a channel.

  ```elixir
  def YourApp.Web do
    # ...
    def channel do
      quote do
        use Phoenix.Channel
        use Airbrake.Channel
        # ...
      end
    end
    # ...
  end
  ```
  """

  defmacro __using__(_env) do
    quote location: :keep do
      @before_compile Airbrake.Channel
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(_env) do
    quote location: :keep do
      defoverridable join: 3, handle_in: 3, handle_info: 2, terminate: 2

      def join(channel_name, msg, socket) do
        super(channel_name, msg, socket)
      rescue
        exception ->
          send_to_airbrake(exception, __STACKTRACE__, socket.assigns, msg, %{channel: channel_name})
      end

      def handle_in(msg_type, msg, socket) do
        super(msg_type, msg, socket)
      rescue
        exception ->
          send_to_airbrake(exception, __STACKTRACE__, socket.assigns, msg, %{msg_type: msg_type})
      end

      def handle_info(msg, socket) do
        super(msg, socket)
      rescue
        exception ->
          send_to_airbrake(exception, __STACKTRACE__, socket.assigns, msg)
      end

      def terminate(reason, socket) do
        super(reason, socket)
      rescue
        exception ->
          send_to_airbrake(exception, __STACKTRACE__, socket.assigns, %{reason: reason})
      end

      defp send_to_airbrake(exception, stacktrace, session, params, context \\ nil) do
        Airbrake.Worker.remember(exception,
          params: params,
          session: session,
          stacktrace: stacktrace,
          context: context
        )

        reraise exception, stacktrace
      end
    end
  end
end
