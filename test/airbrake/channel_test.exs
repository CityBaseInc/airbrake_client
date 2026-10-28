defmodule Airbrake.ChannelTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  import Airbrake.Test
  import Mox

  alias Airbrake.ChannelTest.RoomChannel
  alias Airbrake.MockHTTPoison

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    start_supervised!(Airbrake.Worker)
    :ok
  end

  @socket %{assigns: %{user_id: 42}, topic: "room:lobby"}

  describe "join/3" do
    test "remembers the channel, the topic, and the assigns" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      exception = catch_error(RoomChannel.join("room:lobby", %{"token" => "t"}, @socket))
      Airbrake.report(exception)

      %{"context" => context, "session" => session, "params" => params} = receive_payload()
      assert context["component"] == "Airbrake.ChannelTest.RoomChannel"
      assert context["action"] == "join"
      assert context["route"] == "room:lobby"
      refute Map.has_key?(context, "channel")
      assert session == %{"user_id" => 42}
      assert params == %{"token" => "t"}
    end
  end

  describe "handle_in/3" do
    property "remembers the event as the action" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all event <- string(:alphanumeric, min_length: 1) do
        exception = catch_error(RoomChannel.handle_in(event, %{}, @socket))
        Airbrake.report(exception)

        %{"context" => context} = receive_payload()
        assert context["component"] == "Airbrake.ChannelTest.RoomChannel"
        assert context["action"] == event
        assert context["route"] == "room:lobby"
        refute Map.has_key?(context, "msg_type")
      end
    end

    property "remembers a binary payload in the params" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      check all data <- string(:alphanumeric) do
        exception = catch_error(RoomChannel.handle_in("upload", {:binary, data}, @socket))
        Airbrake.report(exception)

        %{"params" => params} = receive_payload()
        assert params == %{"payload" => ["binary", data]}
      end
    end
  end

  describe "with Airbrake.LoggerBackend" do
    test "adds the details to the notice for an exception with a message of more than one line" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      {exception, stacktrace} =
        try do
          RoomChannel.handle_in("fetch", %{}, @socket)
        rescue
          exception -> {exception, __STACKTRACE__}
        end

      log_message = Exception.format(:error, exception, stacktrace)

      Airbrake.LoggerBackend.handle_event(
        {:error, self(), {Logger, log_message, {{2026, 1, 1}, {0, 0, 0, 0}}, []}},
        nil
      )

      %{"errors" => [error], "context" => context} = receive_payload()
      assert error["type"] == "KeyError"
      assert context["action"] == "fetch"
    end
  end

  describe "handle_info/2 and terminate/2" do
    test "remember the callback as the action" do
      stub(MockHTTPoison, :post, airbrake_post_mock_fun())

      for {action, call} <- [
            {"handle_info", fn -> RoomChannel.handle_info(:tick, @socket) end},
            {"terminate", fn -> RoomChannel.terminate(:shutdown, @socket) end}
          ] do
        exception = catch_error(call.())
        Airbrake.report(exception)

        %{"context" => context} = receive_payload()
        assert context["action"] == action
        assert context["route"] == "room:lobby"
      end
    end

    test "remembers a message that is not a map in the params" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      exception = catch_error(RoomChannel.handle_info(:tick, @socket))
      Airbrake.report(exception)

      %{"params" => params} = receive_payload()
      assert params == %{"message" => "tick"}
    end
  end

  defmodule RoomChannel do
    use Airbrake.Channel

    def join(_topic, _payload, _socket), do: raise("join failed")
    def handle_in("fetch", payload, _socket), do: Map.fetch!(payload, "missing")
    def handle_in(event, _payload, _socket), do: raise("#{event} failed")
    def handle_info(_message, _socket), do: raise("handle_info failed")
    def terminate(_reason, _socket), do: raise("terminate failed")
  end

  defp receive_payload do
    assert_receive {:airbrake_report, %{payload: payload}}, 500
    Jason.decode!(payload)
  end
end
