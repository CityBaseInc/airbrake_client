defmodule Airbrake.GenServerTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  import Airbrake.Test
  import Mox

  alias Airbrake.MockHTTPoison

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    start_supervised!(Airbrake.Worker)
    :ok
  end

  describe "report_termination/2" do
    test "does not report a normal exit" do
      stub(MockHTTPoison, :post, fn _, _, _ -> flunk("should not post a notice") end)

      assert Airbrake.GenServer.report_termination(:normal, %{}) == nil
      refute_receive _any, 200
    end

    property "does not report a shutdown" do
      stub(MockHTTPoison, :post, fn _, _, _ -> flunk("should not post a notice") end)

      check all reason <- one_of([constant(:shutdown), tuple({constant(:shutdown), term()})]) do
        assert Airbrake.GenServer.report_termination(reason, %{}) == nil
      end
    end

    property "reports a raised exception with its message and stacktrace" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all message <- string(:printable, min_length: 1) do
        {exception, stacktrace} = raise_and_rescue(message)

        Airbrake.GenServer.report_termination({exception, stacktrace}, %{process_name: "MyServer"})

        %{"errors" => [error], "context" => context} = receive_payload()
        assert error["type"] == "RuntimeError"
        assert error["message"] == message
        assert [%{"function" => "Elixir.Airbrake.GenServerTest.raise_and_rescue/1"} | _] = error["backtrace"]
        assert context["process_name"] == "MyServer"
      end
    end

    test "reports an Erlang error as an Elixir exception with its stacktrace" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())
      stacktrace = [{MyServer, :handle_call, 3, [file: ~c"lib/my_server.ex", line: 12]}]

      Airbrake.GenServer.report_termination({{:badmatch, 1}, stacktrace}, %{})

      %{"errors" => [error]} = receive_payload()
      assert error["type"] == "MatchError"
      assert error["message"] == Exception.message(%MatchError{term: 1})

      assert error["backtrace"] == [
               %{"file" => "lib/my_server.ex", "line" => 12, "function" => "Elixir.MyServer.handle_call/3"}
             ]
    end

    property "reports any other reason as a RuntimeError with the inspected reason" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all reason <- filter(atom(:alphanumeric), &(&1 not in [:normal, :shutdown])) do
        Airbrake.GenServer.report_termination(reason, %{})

        %{"errors" => [error]} = receive_payload()
        assert error["type"] == "RuntimeError"
        assert error["message"] == inspect(reason)
      end
    end

    property "reports a reason with a list that is not a stacktrace as a RuntimeError" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all tag <- filter(atom(:alphanumeric), &(&1 != :shutdown)),
                list <-
                  list_of(
                    one_of([
                      integer(),
                      tuple({atom(:alphanumeric), atom(:alphanumeric), string(:printable)}),
                      tuple({atom(:alphanumeric), atom(:alphanumeric), atom(:alphanumeric), term()})
                    ])
                  ) do
        Airbrake.GenServer.report_termination({tag, list}, %{})

        %{"errors" => [error]} = receive_payload()
        assert error["type"] == "RuntimeError"
        assert error["message"] == inspect({tag, list})
      end
    end
  end

  describe "use Airbrake.GenServer" do
    test "raises an error that says to use report_termination/2" do
      assert_raise RuntimeError, ~r/Airbrake\.GenServer\.report_termination\/2/, fn ->
        Code.compile_quoted(
          quote do
            defmodule Airbrake.GenServerTest.UsesAirbrakeGenServer do
              use Airbrake.GenServer
            end
          end
        )
      end
    end
  end

  describe "with a GenServer" do
    test "reports a crash from terminate/2" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      ExUnit.CaptureLog.capture_log(fn ->
        Process.flag(:trap_exit, true)
        {:ok, pid} = GenServer.start_link(__MODULE__.Crashy, nil)
        catch_exit(GenServer.call(pid, :boom))
      end)

      %{"errors" => [error], "context" => context} = receive_payload()
      assert error["type"] == "RuntimeError"
      assert error["message"] == "boom"
      assert [%{"function" => "Elixir.Airbrake.GenServerTest.Crashy.handle_call/3"} | _] = error["backtrace"]
      assert context["process_name"] == "Elixir.Airbrake.GenServerTest.Crashy"
    end

    test "reports a crash of a process that Airbrake monitors" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      ExUnit.CaptureLog.capture_log(fn ->
        {:ok, pid} = GenServer.start(__MODULE__.Unreported, nil)
        Airbrake.monitor(pid)
        catch_exit(GenServer.call(pid, :boom))
      end)

      %{"errors" => [error]} = receive_payload()
      assert error["type"] == "RuntimeError"
      assert error["message"] == "boom"
      assert [%{"function" => "Elixir.Airbrake.GenServerTest.Unreported.handle_call/3"} | _] = error["backtrace"]
    end
  end

  defmodule Crashy do
    use GenServer

    @impl GenServer
    def init(state), do: {:ok, state}

    @impl GenServer
    def handle_call(:boom, _from, _state), do: raise("boom")

    @impl GenServer
    def terminate(reason, _state) do
      Airbrake.GenServer.report_termination(reason, %{process_name: __MODULE__})
      :ok
    end
  end

  defmodule Unreported do
    use GenServer

    @impl GenServer
    def init(state), do: {:ok, state}

    @impl GenServer
    def handle_call(:boom, _from, _state), do: raise("boom")
  end

  defp raise_and_rescue(message) do
    raise message
  rescue
    exception -> {exception, __STACKTRACE__}
  end

  defp receive_payload do
    assert_receive {:airbrake_report, %{payload: payload}}, 500
    Jason.decode!(payload)
  end
end
