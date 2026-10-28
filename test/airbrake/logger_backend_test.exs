defmodule Airbrake.LoggerBackendTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  import Airbrake.Test
  import ExUnit.CaptureLog
  import Mox

  alias Airbrake.{LoggerBackend, MockHTTPoison}

  require Logger

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    {:ok, _} = Application.ensure_all_started(:logger_backends)
    {:ok, _} = LoggerBackends.add({LoggerBackend, :error})
    on_exit(fn -> LoggerBackends.remove({LoggerBackend, :error}) end)
    start_supervised!(Airbrake.Worker)
    :ok
  end

  describe "error handling" do
    test "sends the error via the HTTP handler" do
      error_message = "** (FunctionClauseError) no function clause matching in Enum.join/2"

      expected_payload_errors =
        "\"errors\":[{\"type\":\"FunctionClauseError\",\"message\":\"no function clause matching in Enum.join/2\",\"backtrace\":[]}]"

      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      assert capture_log(fn ->
               Logger.error(error_message)
             end) =~ error_message

      assert_receive {:airbrake_report, %{payload: payload}}, 500
      assert payload =~ expected_payload_errors
    end

    test "raises Airbrake for RuntimeError from raise" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      capture_log(fn ->
        try do
          raise "test exception"
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
        end
      end)

      assert_receive {:airbrake_report, %{payload: payload}}, 500
      assert payload =~ "\"type\":\"RuntimeError\""
      assert payload =~ "\"message\":\"test exception\""
    end

    test "raises Airbrake for ArgumentError" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      capture_log(fn ->
        try do
          Integer.to_string(1.0)
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
        end
      end)

      assert_receive {:airbrake_report, %{payload: payload}}, 500
      assert payload =~ "\"type\":\"ArgumentError\""
    end

    test "does NOT raise Airbrake for plain text Logger.error" do
      stub(MockHTTPoison, :post, fn _, _, _ ->
        flunk("MockHTTPoison.post should not be called for plain text error logs")
      end)

      capture_log(fn ->
        Logger.error("foo bar")
      end)

      refute_receive _any, 500
    end

    test "reports only the frames of the GenServer for a GenServer crash" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      capture_log(fn ->
        Process.flag(:trap_exit, true)
        {:ok, pid} = GenServer.start_link(__MODULE__.Crashy, %{})
        catch_exit(GenServer.call(pid, :boom))
      end)

      %{"errors" => [error], "session" => session} = receive_payload()
      functions = Enum.map(error["backtrace"], & &1["function"])

      assert error["type"] == "RuntimeError"
      assert error["message"] == "boom"
      assert Enum.any?(functions, &(&1 =~ "Crashy.handle_call/3"))
      refute Enum.any?(functions, &(&1 =~ "GenServer.call/3"))
      assert session["state"] == "%{}"
      assert session["title"] =~ ~r/\AGenServer #PID<.*> terminating\z/
    end
  end

  describe "parsing the log message" do
    setup do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())
      :ok
    end

    test "puts a frame without an app in the backtrace" do
      log_error("""
      ** (RuntimeError) boom
          lib/my_app/foo.ex:13: MyApp.Foo.bar/1
          (elixir 1.20.4) lib/gen_server.ex:1180: GenServer.call/3
      """)

      %{"errors" => [error], "session" => session} = receive_payload()

      assert error["backtrace"] == [
               %{"file" => "lib/my_app/foo.ex", "line" => 13, "function" => "MyApp.Foo.bar/1"},
               %{"file" => "lib/gen_server.ex", "line" => 1180, "function" => "(elixir 1.20.4) GenServer.call/3"}
             ]

      assert session == nil
    end

    test "uses only the frames right after the exception for the backtrace" do
      log_error("""
      GenServer #PID<0.104.0> terminating
      ** (RuntimeError) boom
          lib/crashy.ex:4: Crashy.handle_call/3
          (stdlib 6.2.1) gen_server.erl:2381: :gen_server.try_handle_call/4
      Last message (from #PID<0.94.0>): :boom
      State: %{a: 1}
      Client #PID<0.94.0> is alive

          (stdlib 6.2.1) gen.erl:260: :gen.do_call/4
          lib/caller.ex:8: Caller.go/2
      """)

      %{"errors" => [error], "session" => session} = receive_payload()

      assert Enum.map(error["backtrace"], & &1["function"]) == [
               "Crashy.handle_call/3",
               "(stdlib 6.2.1) :gen_server.try_handle_call/4"
             ]

      assert session == %{
               "title" => "GenServer #PID<0.104.0> terminating",
               "last message (from #pid<0.94.0>)" => ":boom",
               "state" => "%{a: 1}"
             }
    end

    test "does not use the frames of the client for a GenServer that stops without an exception" do
      log_error("""
      GenServer #PID<0.219.0> terminating
      ** (stop) :bad_thing
      Last message (from #PID<0.220.0>): :stop
      State: %{a: 1}
      Client #PID<0.220.0> is alive

          (stdlib 8.1.1) gen.erl:262: :gen.do_call/4
          (elixir 1.20.4) lib/gen_server.ex:1180: GenServer.call/3
      """)

      %{"errors" => [error], "session" => session} = receive_payload()

      assert error["type"] == "stop"
      assert error["message"] == ":bad_thing"
      assert error["backtrace"] == []

      assert session == %{
               "title" => "GenServer #PID<0.219.0> terminating",
               "last message (from #pid<0.220.0>)" => ":stop",
               "state" => "%{a: 1}"
             }
    end

    test "uses the frames of a nested exception for the backtrace" do
      log_error("""
      Task #PID<0.215.0> started from #PID<0.94.0> terminating
      ** (stop) exited in: GenServer.call(#PID<0.214.0>, :boom, 5000)
          ** (EXIT) an exception was raised:
              ** (RuntimeError) boom
                  lib/callee.ex:4: Callee.handle_call/3
                  (stdlib 8.1.1) gen_server.erl:2470: :gen_server.try_handle_call/4
          (elixir 1.20.4) lib/gen_server.ex:1183: GenServer.call/3
          (elixir 1.20.4) lib/task/supervised.ex:105: Task.Supervised.invoke_mfa/2
      Function: #Function<0.81797565 in Caller.go/0>
          Args: []
      """)

      %{"errors" => [error], "session" => session} = receive_payload()

      assert error["type"] == "RuntimeError"
      assert error["message"] == "boom"

      assert Enum.map(error["backtrace"], & &1["function"]) == [
               "Callee.handle_call/3",
               "(stdlib 8.1.1) :gen_server.try_handle_call/4"
             ]

      assert session == %{
               "title" => "Task #PID<0.215.0> started from #PID<0.94.0> terminating",
               "reason" =>
                 "** (stop) exited in: GenServer.call(#PID<0.214.0>, :boom, 5000)\n** (EXIT) an exception was raised:",
               "function" => "#Function<0.81797565 in Caller.go/0>",
               "args" => "[]"
             }
    end

    test "uses the frames of the caller for a nested exit without its own frames" do
      log_error("""
      Task #PID<0.220.0> started from #PID<0.94.0> terminating
      ** (stop) exited in: GenServer.call(#PID<0.219.0>, :slow, 50)
          ** (EXIT) time out
          (elixir 1.20.4) lib/gen_server.ex:1183: GenServer.call/3
          (elixir 1.20.4) lib/task/supervised.ex:105: Task.Supervised.invoke_mfa/2
      Function: #Function<2.81797565 in Caller.go/0>
          Args: []
      """)

      %{"errors" => [error], "session" => session} = receive_payload()

      assert error["type"] == "EXIT"
      assert error["message"] == "time out"

      assert Enum.map(error["backtrace"], & &1["function"]) == [
               "(elixir 1.20.4) GenServer.call/3",
               "(elixir 1.20.4) Task.Supervised.invoke_mfa/2"
             ]

      assert session["reason"] == "** (stop) exited in: GenServer.call(#PID<0.219.0>, :slow, 50)"
    end

    test "finds the backtrace after an exception message with more than one line" do
      # The message of a KeyError has more than one line only in Elixir 1.19+.
      try do
        Map.fetch!(Process.get(:airbrake_test_map, %{abc: 1}), :abd)
      rescue
        e in KeyError ->
          log_error(
            Exception.format(:error, %{e | message: "key :abd not found in:\n\n    %{abc: 1}\n"}, __STACKTRACE__)
          )
      end

      %{"errors" => [error], "session" => session} = receive_payload()

      assert error["type"] == "KeyError"
      assert error["message"] == "key :abd not found in:"
      assert Enum.any?(error["backtrace"], &(&1["function"] =~ "map_get"))
      assert session == nil
    end
  end

  describe "properties" do
    property "puts each Key: value line in the session without making an atom" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all suffix <- string(:alphanumeric, min_length: 1),
                value <- string(:alphanumeric, min_length: 1) do
        key = "Airbrake Test Key #{suffix} #{System.unique_integer([:positive])}"

        log_error("** (RuntimeError) boom\n#{key}: #{value}")

        %{"session" => session} = receive_payload()
        assert session[String.downcase(key)] == value
        assert_raise ArgumentError, fn -> String.to_existing_atom(String.downcase(key)) end
      end
    end

    property "never sets a context field from the log message" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all key <- member_of(~w(Environment Hostname Severity Component Action Url User Version Route)),
                value <- string(:alphanumeric, min_length: 1) do
        log_error("** (RuntimeError) boom\n#{key}: #{value}")

        %{"context" => context, "session" => session} = receive_payload()
        assert Map.keys(context) == ["environment", "hostname"]
        refute context["environment"] == value
        assert session[String.downcase(key)] == value
      end
    end

    property "ignores the other lines of a multi-line exception message" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all message_lines <- list_of(message_line(), min_length: 1),
                function_names <- list_of(string(:alphanumeric, min_length: 1), min_length: 1) do
        frames = Enum.map(function_names, &"    (my_app 0.1.0) lib/my_app.ex:12: MyApp.#{&1}/1")

        log_error(Enum.join(["** (RuntimeError) boom" | message_lines] ++ frames, "\n"))

        %{"errors" => [error], "session" => session} = receive_payload()
        assert error["message"] == "boom"

        assert Enum.map(error["backtrace"], & &1["function"]) ==
                 Enum.map(function_names, &"(my_app 0.1.0) MyApp.#{&1}/1")

        assert session == nil
      end
    end

    property "uses only the frames of the innermost exception for the backtrace" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all depth <- integer(0..4),
                inner_names <- list_of(string(:alphanumeric, min_length: 1), min_length: 1),
                outer_names <- list_of(string(:alphanumeric, min_length: 1)) do
        outer_lines =
          for level <- 0..(depth - 1)//1, do: indent(level) <> "** (EXIT) exited in: GenServer.call(:a, :b, 5000)"

        inner_frames = Enum.map(inner_names, &(indent(depth + 1) <> "lib/inner.ex:4: Inner.#{&1}/1"))
        outer_frames = Enum.map(outer_names, &(indent(1) <> "lib/outer.ex:8: Outer.#{&1}/2"))
        exception_line = indent(depth) <> "** (RuntimeError) boom"

        log_error(Enum.join(outer_lines ++ [exception_line | inner_frames] ++ outer_frames, "\n"))

        %{"errors" => [error]} = receive_payload()

        expected_functions =
          if depth == 0,
            do: Enum.map(inner_names, &"Inner.#{&1}/1") ++ Enum.map(outer_names, &"Outer.#{&1}/2"),
            else: Enum.map(inner_names, &"Inner.#{&1}/1")

        assert Enum.map(error["backtrace"], & &1["function"]) == expected_functions
      end
    end

    property "never raises, whatever the message" do
      stub(MockHTTPoison, :post, fn _url, _payload, _headers -> {:ok, %HTTPoison.Response{status_code: 201}} end)

      check all lines <- list_of(string(:printable, max_length: 300)),
                index <- integer(0..length(lines)) do
        message = lines |> List.insert_at(index, "** (RuntimeError) boom") |> Enum.join("\n")
        assert log_error(message) == {:ok, nil}
      end
    end
  end

  defmodule Crashy do
    use GenServer

    @impl GenServer
    def init(state), do: {:ok, state}

    @impl GenServer
    def handle_call(:boom, _from, _state), do: raise("boom")
  end

  # A line of an exception message after its first line, like the "    %{abc: 1}" line of a KeyError.
  defp message_line do
    one_of([constant(""), string(:alphanumeric, min_length: 1), map(string(:alphanumeric), &"    #{&1}")])
  end

  defp indent(level), do: String.duplicate("    ", level)

  defp log_error(message) do
    LoggerBackend.handle_event({:error, self(), {Logger, message, {{2026, 1, 1}, {0, 0, 0, 0}}, []}}, nil)
  end

  defp receive_payload do
    assert_receive {:airbrake_report, %{payload: payload}}, 500
    Jason.decode!(payload)
  end
end
