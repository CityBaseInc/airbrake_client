defmodule Airbrake.Channel do
  @moduledoc """
  Adds the details of the channel to the notice for an error in a channel.

  `Airbrake.Channel` does not post a notice itself. It remembers the details of
  the channel, and `Airbrake.LoggerBackend` adds them to the notice when it
  reports the same error from the log. Set up `Airbrake.LoggerBackend` too, or
  the details are never sent. Only the details of the latest error are
  remembered, so if another error happens before the backend reports the
  first one, the notice for the first one does not have its details.

  ```elixir
  defmodule YourApp.Web do
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

  The context of the notice has the channel module as its `component`, the
  event (or `"join"`, `"handle_info"`, or `"terminate"`) as its `action`, and
  the topic as its `route`. The params are the payload of the message, and the
  session is the assigns of the socket. A payload that is not a map, such as
  `{:binary, data}`, is in the params as `payload`.
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
          send_to_airbrake(exception, __STACKTRACE__, socket, msg, "join", channel_name)
      end

      def handle_in(msg_type, msg, socket) do
        super(msg_type, msg, socket)
      rescue
        exception ->
          # The payload is not a map for a binary message ({:binary, data}).
          params = if is_map(msg), do: msg, else: %{payload: msg}
          send_to_airbrake(exception, __STACKTRACE__, socket, params, msg_type, socket.topic)
      end

      def handle_info(msg, socket) do
        super(msg, socket)
      rescue
        exception ->
          send_to_airbrake(exception, __STACKTRACE__, socket, %{message: msg}, "handle_info", socket.topic)
      end

      def terminate(reason, socket) do
        super(reason, socket)
      rescue
        exception ->
          send_to_airbrake(exception, __STACKTRACE__, socket, %{reason: reason}, "terminate", socket.topic)
      end

      # component, action, and route are context fields that Airbrake recognizes.
      defp send_to_airbrake(exception, stacktrace, socket, params, action, topic) do
        Airbrake.Worker.remember(exception,
          params: params,
          session: socket.assigns,
          stacktrace: stacktrace,
          context: %{component: inspect(__MODULE__), action: action, route: topic}
        )

        reraise exception, stacktrace
      end
    end
  end
end
