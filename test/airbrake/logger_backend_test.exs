defmodule Airbrake.LoggerBackendTest do
  use ExUnit.Case, async: false

  import Mox
  import ExUnit.CaptureLog
  import Airbrake.Test
  require Logger

  alias Airbrake.{LoggerBackend, MockHTTPoison}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Logger.add_backend({LoggerBackend, :error})
    Airbrake.start()
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
  end
end
