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

      assert Airbrake.GenServer.report_termination(:normal) == nil
      refute_receive _any, 200
    end

    property "does not report a shutdown" do
      stub(MockHTTPoison, :post, fn _, _, _ -> flunk("should not post a notice") end)

      check all reason <- one_of([constant(:shutdown), tuple({constant(:shutdown), term()})]) do
        assert Airbrake.GenServer.report_termination(reason) == nil
      end
    end

    property "reports a raised exception with its message and stacktrace" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all message <- string(:printable, min_length: 1) do
        {exception, stacktrace} = raise_and_rescue(message)

        Airbrake.GenServer.report_termination({exception, stacktrace})

        %{"errors" => [error]} = receive_payload()
        assert error["type"] == "RuntimeError"
        assert error["message"] == message
        assert [%{"function" => "Elixir.Airbrake.GenServerTest.raise_and_rescue/1"} | _] = error["backtrace"]
      end
    end

    test "reports an exception with an empty stacktrace" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      Airbrake.GenServer.report_termination({ArgumentError.exception("bad argument"), []})

      %{"errors" => [error]} = receive_payload()
      assert error["type"] == "ArgumentError"
      assert error["message"] == "bad argument"
      assert error["backtrace"] == []
    end

    property "passes the options to Airbrake.report/2" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all component <- string(:alphanumeric, min_length: 1),
                value <- string(:alphanumeric, min_length: 1),
                reason <- one_of([constant(:kill), constant(:oops)]) do
        Airbrake.GenServer.report_termination(reason, context: %{component: component}, session: %{"key" => value})

        %{"context" => context, "session" => session} = receive_payload()
        assert context["component"] == component
        assert session == %{"key" => value}
      end
    end

    test "reports an Erlang error as an Elixir exception with its stacktrace" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())
      stacktrace = [{MyServer, :handle_call, 3, [file: ~c"lib/my_server.ex", line: 12]}]

      Airbrake.GenServer.report_termination({{:badmatch, 1}, stacktrace})

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
        Airbrake.GenServer.report_termination(reason)

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
        Airbrake.GenServer.report_termination({tag, list})

        %{"errors" => [error]} = receive_payload()
        assert error["type"] == "RuntimeError"
        assert error["message"] == inspect({tag, list})
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
      assert context["component"] == "Airbrake.GenServerTest.Crashy"
    end

    test "reports a crash of a process that Airbrake monitors" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      {pid, _log} =
        ExUnit.CaptureLog.with_log(fn ->
          {:ok, pid} = GenServer.start(__MODULE__.Unreported, nil)
          Airbrake.monitor(pid)
          wait_for_worker()
          catch_exit(GenServer.call(pid, :boom))
          pid
        end)

      %{"errors" => [error], "context" => context, "session" => session} = receive_payload()
      assert error["type"] == "RuntimeError"
      assert error["message"] == "boom"
      assert [%{"function" => "Elixir.Airbrake.GenServerTest.Unreported.handle_call/3"} | _] = error["backtrace"]
      assert Map.keys(context) == ["environment", "hostname"]
      assert session == %{"process" => inspect(pid)}
    end

    test "reports the name of a registered process that Airbrake monitors as the component" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())
      name = __MODULE__.Registered

      ExUnit.CaptureLog.capture_log(fn ->
        {:ok, _pid} = GenServer.start(__MODULE__.Unreported, nil, name: name)
        Airbrake.monitor(name)
        wait_for_worker()
        catch_exit(GenServer.call(name, :boom))
      end)

      %{"context" => context, "session" => session} = receive_payload()
      assert context["component"] == "Airbrake.GenServerTest.Registered"
      assert session == %{"process" => inspect({name, node()})}
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
      Airbrake.GenServer.report_termination(reason, context: %{component: inspect(__MODULE__)})
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

  # Airbrake.monitor/1 casts to the worker, so a process can exit before the worker monitors it. The worker handles
  # the cast before this call.
  defp wait_for_worker, do: :sys.get_state(Airbrake.Worker)
end
