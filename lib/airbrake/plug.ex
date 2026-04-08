defmodule Airbrake.Plug do
  @moduledoc """
  Reports any error encountered in the plug pipeline.

  To use this plug, add it to your router:

  ```elixir
  defmodule MyApp.Router do
    use Phoenix.Router
    use Airbrake.Plug # <- put this line in your router

    # ...
  end
  ```
  """

  defmacro __using__(_env) do
    quote location: :keep do
      use Plug.ErrorHandler

      def handle_errors(conn, %{kind: :error, reason: exception, stack: stacktrace}) do
        conn = conn |> Plug.Conn.fetch_cookies() |> Plug.Conn.fetch_query_params()
        headers = Enum.into(conn.req_headers, %{})

        conn_data = %{
          url: "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}",
          userIP: conn.remote_ip |> :inet.ntoa() |> to_string(),
          userAgent: headers["user-agent"],
          cookies: conn.req_cookies
        }

        environment = %{
          headers: headers,
          httpMethod: conn.method
        }

        Airbrake.Worker.remember(
          exception,
          params: conn.params,
          session: conn.private[:plug_session],
          context: conn_data,
          env: environment,
          stacktrace: stacktrace
        )
      end

      def handle_errors(_conn, _map), do: nil
    end
  end
end
