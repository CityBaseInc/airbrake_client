defmodule Airbrake.PlugTest do
  use ExUnit.Case, async: false

  import Airbrake.Test
  import Mox

  alias Airbrake.MockHTTPoison
  alias Airbrake.PlugTest.Router

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    start_supervised!(Airbrake.Worker)
    :ok
  end

  test "remembers only context fields that Airbrake recognizes" do
    expect(MockHTTPoison, :post, airbrake_post_mock_fun())

    conn =
      :get
      |> Plug.Test.conn("/boom?page=3")
      |> Plug.Conn.put_req_header("user-agent", "TestAgent/1.0")
      |> Plug.Conn.put_req_header("cookie", "secret=abc")

    catch_error(Router.call(conn, Router.init([])))
    Airbrake.report(RuntimeError.exception("boom"))

    %{"context" => context, "environment" => environment, "params" => params} = receive_payload()

    assert context == %{
             "environment" => context["environment"],
             "hostname" => context["hostname"],
             "url" => "http://www.example.com:80/boom",
             "userAddr" => "127.0.0.1",
             "userAgent" => "TestAgent/1.0"
           }

    assert environment["headers"]["cookie"] == "secret=abc"
    assert environment["httpMethod"] == "GET"
    assert params == %{"page" => "3"}
  end

  defmodule Router do
    use Plug.Router
    use Airbrake.Plug

    plug(:match)
    plug(:dispatch)

    get "/boom" do
      _ = conn
      raise "boom"
    end
  end

  defp receive_payload do
    assert_receive {:airbrake_report, %{payload: payload}}, 500
    Jason.decode!(payload)
  end
end
