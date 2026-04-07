defmodule Airbrake.LoggerBackendTest do
  use ExUnit.Case, async: false

  import Mox
  import ExUnit.CaptureLog
  require Logger

  alias Airbrake.{HTTPMock, LoggerBackend}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Logger.add_backend({LoggerBackend, :error})
    Airbrake.start()
    :ok
  end

  describe "error handling" do
    test "sends the error via the HTTP handler" do
      caller = self()
      error_message = "** (FunctionClauseError) no function clause matching in Enum.join/2"

      expected_payload_errors =
        "\"errors\":[{\"type\":\"FunctionClauseError\",\"message\":\"no function clause matching in Enum.join/2\",\"backtrace\":[]}]"

      expect(HTTPMock, :post, fn url, payload, _headers ->
        assert payload =~ expected_payload_errors
        send(caller, url: url, payload: payload)
        {:ok, %{status_code: 204}}
      end)

      assert capture_log(fn ->
               Logger.error(error_message)
             end) =~ error_message

      assert_receive(url: _url, payload: _http_payload)
    end

    test "raises Airbrake for RuntimeError from raise" do
      caller = self()

      expect(HTTPMock, :post, fn url, payload, _headers ->
        assert payload =~ "\"type\":\"RuntimeError\""
        assert payload =~ "\"message\":\"test exception\""
        send(caller, url: url, payload: payload)
        {:ok, %{status_code: 204}}
      end)

      capture_log(fn ->
        try do
          raise "test exception"
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
        end
      end)

      assert_receive(url: _url, payload: _http_payload)
    end

    test "raises Airbrake for ArgumentError" do
      caller = self()

      expect(HTTPMock, :post, fn url, payload, _headers ->
        assert payload =~ "\"type\":\"ArgumentError\""
        send(caller, url: url, payload: payload)
        {:ok, %{status_code: 204}}
      end)

      capture_log(fn ->
        try do
          Integer.to_string(1.0)
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
        end
      end)

      assert_receive(url: _url, payload: _http_payload)
    end

    test "does NOT raise Airbrake for plain text Logger.error" do
      stub(HTTPMock, :post, fn _, _, _ ->
        flunk("HTTPMock.post should not be called for plain text error logs")
      end)

      capture_log(fn ->
        Logger.error("foo bar")
      end)

      refute_receive(_any, 100)
    end
  end
end
