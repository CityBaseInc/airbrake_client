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

  The notice has the URL, the client address, and the user agent in its
  context, the request headers in its environment, the params, and the `Plug`
  session. Cookies are in the `"cookie"` header, so add `"cookie"` to
  `:filter_headers` to filter them.
  """

  defmacro __using__(_env) do
    quote location: :keep do
      use Plug.ErrorHandler

      def handle_errors(conn, %{kind: :error, reason: exception, stack: stacktrace}) do
        conn = Plug.Conn.fetch_query_params(conn)
        headers = Enum.into(conn.req_headers, %{})

        # url, userAddr, and userAgent are context fields that Airbrake recognizes. Cookies are in the
        # "cookie" header, where :filter_headers can filter them.
        conn_data = %{
          url: "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}",
          userAddr: conn.remote_ip |> :inet.ntoa() |> to_string(),
          userAgent: headers["user-agent"]
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
