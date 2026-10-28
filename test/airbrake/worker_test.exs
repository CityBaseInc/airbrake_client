defmodule Airbrake.WorkerTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  import Airbrake.Test
  import Mox

  alias Airbrake.{MockHTTPoison, Payload}
  alias Airbrake.Worker.State

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    worker_pid = start_supervised!(Airbrake.Worker)

    {exception, stacktrace} =
      try do
        Enum.join(3, ~c"million")
      rescue
        exception -> {exception, __STACKTRACE__}
      end

    [exception: exception, stacktrace: stacktrace, worker_pid: worker_pid]
  end

  describe "report/1" do
    test "sends the exception and stacktrace to Airbrake", %{exception: exception, stacktrace: stacktrace} do
      expected_payload =
        exception
        |> Payload.new(stacktrace)
        |> Map.from_struct()

      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      Airbrake.Worker.report(exception, stacktrace: stacktrace)

      assert_receive {:airbrake_report, %{payload: http_payload}}, 500

      decoded_http_payload =
        http_payload
        |> Poison.decode!()
        |> atomize_keys()

      assert decoded_http_payload == expected_payload
    end

    test "sends the report to the right URL", %{exception: exception, stacktrace: stacktrace} do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      Airbrake.Worker.report(exception, stacktrace: stacktrace)

      assert_receive {:airbrake_report, %{url: url}}, 500

      # Uses default host from Airbrake.Worker.
      # Uses project id and api key from config/test.exs.
      assert url == "https://api.airbrake.io/api/v3/projects/8675309/notices?key=TESTING_API_KEY"
    end

    test "generates a stacktrace if one is not provided", %{exception: exception} do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      Airbrake.Worker.report(exception)

      assert_receive {:airbrake_report, %{payload: http_payload}}, 500

      assert %{"errors" => [only_error]} = http_payload |> Poison.decode!()
      assert %{"backtrace" => stacktrace} = only_error

      assert [
               %{"function" => "Elixir.Process.info/2"},
               %{"function" => "Elixir.Airbrake.Worker.get_stacktrace/0"},
               %{"function" => "Elixir.Airbrake.Worker.report/2"},
               # this stacktrace traces back to THIS test
               %{
                 "function" =>
                   "Elixir.Airbrake.WorkerTest.test report/1 generates a stacktrace if one is not provided/1"
               }
               | _
             ] = stacktrace
    end
  end

  describe "remember/1" do
    setup do
      stub(Airbrake.MockHTTPoison, :post, fn _url, _payload, _headers ->
        {:ok, %{status_code: 201}}
      end)

      :ok
    end

    test "saves exception info in state", %{exception: exception, worker_pid: worker_pid} do
      expected_state = [type: inspect(exception.__struct__), message: Exception.message(exception)]

      Airbrake.Worker.remember(exception)

      assert %State{last_exception: {last_exception, _options}} = :sys.get_state(worker_pid)
      assert last_exception == expected_state
    end
  end

  describe "report/2 after remember/2" do
    property "adds the remembered details when the message is the first line of the remembered message" do
      stub(Airbrake.MockHTTPoison, :post, airbrake_post_mock_fun())

      check all type <- string(:alphanumeric, min_length: 1),
                first_line <- string(:alphanumeric, min_length: 1),
                other_lines <- list_of(string(:alphanumeric)) do
        message = Enum.join([first_line | other_lines], "\n")
        Airbrake.Worker.remember([type: type, message: message], context: %{component: "Remembered"})

        Airbrake.Worker.report([type: type, message: first_line], [])

        assert_receive {:airbrake_report, %{payload: payload}}, 500
        assert Poison.decode!(payload)["context"]["component"] == "Remembered"
      end
    end

    property "does not add the remembered details for another exception" do
      stub(Airbrake.MockHTTPoison, :post, airbrake_post_mock_fun())

      check all type <- string(:alphanumeric, min_length: 1),
                message <- string(:alphanumeric, min_length: 1),
                other_message <- string(:alphanumeric, min_length: 1),
                other_message != message do
        Airbrake.Worker.remember([type: type, message: message], context: %{component: "Remembered"})

        Airbrake.Worker.report([type: type, message: other_message], [])

        assert_receive {:airbrake_report, %{payload: payload}}, 500
        refute Map.has_key?(Poison.decode!(payload)["context"], "component")
      end
    end

    property "merges a keyword list with the remembered details" do
      stub(Airbrake.MockHTTPoison, :post, airbrake_post_mock_fun())
      exception = [type: "RuntimeError", message: "boom"]

      check all key <- member_of([:context, :session]),
                value <- string(:alphanumeric) do
        Airbrake.Worker.remember(exception, [{key, %{remembered: "detail"}}])

        Airbrake.Worker.report(exception, [{key, [reported: value]}])

        assert_receive {:airbrake_report, %{payload: payload}}, 500
        assert %{"remembered" => "detail", "reported" => ^value} = Poison.decode!(payload)[to_string(key)]
      end
    end

    property "posts a notice for params of any kind", %{worker_pid: worker_pid} do
      stub(Airbrake.MockHTTPoison, :post, airbrake_post_mock_fun())
      exception = [type: "RuntimeError", message: "boom"]

      check all reported <-
                  one_of([
                    constant(nil),
                    string(:alphanumeric),
                    list_of(integer()),
                    map_of(atom(:alphanumeric), integer())
                  ]),
                remembered <-
                  one_of([
                    constant(nil),
                    string(:alphanumeric),
                    list_of(integer()),
                    map_of(atom(:alphanumeric), integer())
                  ]) do
        Airbrake.Worker.remember(exception, params: remembered)

        Airbrake.Worker.report(exception, params: reported)

        assert_receive {:airbrake_report, _}, 500
        assert %State{} = :sys.get_state(worker_pid)
      end
    end
  end

  describe "monitor/1" do
    property "returns an error for anything other than a pid or an atom", %{worker_pid: worker_pid} do
      check all target <- term(),
                not is_pid(target) and not is_atom(target) do
        assert Airbrake.Worker.monitor(target) == {:error, ArgumentError}
        assert %State{} = :sys.get_state(worker_pid)
      end
    end
  end

  describe "format_status/1" do
    property "redacts the remembered exception from the state", %{worker_pid: worker_pid} do
      check all secret <- map(string(:alphanumeric, min_length: 1), &"secret-#{&1}") do
        Airbrake.Worker.remember([type: "RuntimeError", message: secret], params: %{"password" => secret})

        status = inspect(:sys.get_status(worker_pid), limit: :infinity)

        assert status =~ "RuntimeError"
        refute status =~ secret
      end
    end

    property "redacts the last message" do
      check all secret <- map(string(:alphanumeric, min_length: 1), &"secret-#{&1}"),
                message <-
                  member_of([
                    {:"$gen_cast", {:report, [type: "RuntimeError", message: secret], [], params: secret}},
                    {:"$gen_cast", {:remember, [type: "RuntimeError", message: secret], params: secret}},
                    {:"$gen_cast", {:monitor, secret}},
                    {:DOWN, make_ref(), :process, self(), {RuntimeError.exception(secret), []}},
                    {:unexpected, secret}
                  ]) do
        status = Airbrake.Worker.format_status(%{state: %State{}, message: message})

        refute inspect(status, limit: :infinity) =~ secret
      end
    end

    property "redacts the messages and states in the sys log", %{worker_pid: worker_pid} do
      :ok = :sys.log(worker_pid, true)

      check all secret <- map(string(:alphanumeric, min_length: 1), &"secret-#{&1}") do
        Airbrake.Worker.remember([type: "RuntimeError", message: secret], params: %{"password" => secret})

        # The raw debug options come from :sys, not from format_status/1.
        {:status, _pid, _module, [_pdict, _sys_state, _parent, _debug, status]} = :sys.get_status(worker_pid)

        assert inspect(status, limit: :infinity) =~ "Logged events"
        refute inspect(status, limit: :infinity) =~ secret
      end
    end
  end

  describe "an unexpected message" do
    property "does not crash the worker", %{worker_pid: worker_pid} do
      check all message <- term(),
                not match?({:DOWN, _, _, _, _}, message) do
        send(worker_pid, message)

        assert %State{} = :sys.get_state(worker_pid)
      end
    end
  end

  @spec atomize_keys(any()) :: map()
  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), atomize_keys(v)} end)
    |> Enum.into(%{})
  end

  defp atomize_keys([head | rest]) do
    [atomize_keys(head) | atomize_keys(rest)]
  end

  defp atomize_keys(other), do: other
end
