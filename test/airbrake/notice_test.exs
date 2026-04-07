defmodule Airbrake.NoticeTest do
  use ExUnit.Case, async: false

  import Airbrake.Test
  import ExUnit.CaptureIO
  import Mox

  alias Airbrake.MockHTTPoison

  defmodule RaisingPayloadProcessor do
    @behaviour Airbrake.PayloadProcessor

    @impl true
    def process_params(_params, _opts), do: raise("payload processing error")

    @impl true
    def process_headers(_headers, _opts), do: raise("payload processing error")

    @impl true
    def encode!(_payload), do: raise("encode error")
  end

  defmodule ThrowingPayloadProcessor do
    @behaviour Airbrake.PayloadProcessor

    @impl true
    def process_params(_params, _opts), do: throw(:payload_processing_error)

    @impl true
    def process_headers(_headers, _opts), do: throw(:payload_processing_error)

    @impl true
    def encode!(_payload), do: throw(:encode_error)
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  @exception [type: "RuntimeError", message: "test error"]
  @stacktrace []

  @fallback_payload ~s({"errors":[{"type":"Airbrake.Notice.Error","message":"airbrake_client failed to process an error notice"}]})

  describe "post_notice/3" do
    test "posts the encoded payload to Airbrake" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      Airbrake.Notice.post_notice(@exception, @stacktrace, [])

      assert_receive {:airbrake_report, %{url: url, payload: payload}}, 500
      assert url =~ "api/v3/projects"
      assert %{"errors" => [%{"type" => "RuntimeError", "message" => "test error"}]} = Poison.decode!(payload)
    end

    test "encodes the `Airbrake.Payload` to JSON" do
      stub(MockConfig, :payload_processor, fn -> Airbrake.JasonPayloadProcessor end)

      assert %{
               "params" => %{
                 "name" => "Alice"
               }
             } =
               %Airbrake.Payload{
                 params: %{
                   "name" => "Alice"
                 }
               }
               |> Airbrake.Notice.json_encode(config: MockConfig)
               |> Jason.decode!()
    end
  end

  describe "post_notice/3 when payload processing raises" do
    setup do
      setup_raising_payload_processor()
    end

    test "sends a fallback notice instead of crashing" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      capture_io(:stderr, fn ->
        Airbrake.Notice.post_notice(@exception, @stacktrace, [])
      end)

      assert_receive {:airbrake_report, %{payload: @fallback_payload}}, 500
    end
  end

  describe "post_notice/3 when payload processing throws" do
    setup do
      setup_throwing_payload_processor()
    end

    test "sends a fallback notice instead of crashing" do
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      capture_io(:stderr, fn ->
        Airbrake.Notice.post_notice(@exception, @stacktrace, [])
      end)

      assert_receive {:airbrake_report, %{payload: @fallback_payload}}, 500
    end
  end

  describe "post_notice/3 when payload processing raises and fallback also fails" do
    setup do
      setup_raising_payload_processor()
    end

    test "returns :error without crashing" do
      stub(MockHTTPoison, :post, fn _url, _payload, _headers ->
        raise "HTTP adapter error"
      end)

      result =
        capture_io(:stderr, fn ->
          result = Airbrake.Notice.post_notice(@exception, @stacktrace, [])
          send(self(), {:result, result})
        end)

      assert result =~ "airbrake_client failed"
      assert_receive {:result, :error}
    end
  end

  describe "post_notice/3 when the HTTP adapter raises" do
    test "sends a fallback notice instead of crashing" do
      caller = self()

      expect(MockHTTPoison, :post, fn _url, _payload, _headers ->
        raise "HTTP adapter error"
      end)

      expect(MockHTTPoison, :post, fn url, payload, headers ->
        send(caller, {:airbrake_report, %{url: url, payload: payload, headers: headers}})
        {:ok, %HTTPoison.Response{status_code: 201}}
      end)

      capture_io(:stderr, fn ->
        Airbrake.Notice.post_notice(@exception, @stacktrace, [])
      end)

      assert_receive {:airbrake_report, %{payload: @fallback_payload}}, 500
    end
  end

  defp setup_raising_payload_processor do
    original = Application.get_env(:airbrake_client, :payload_processor)
    Application.put_env(:airbrake_client, :payload_processor, RaisingPayloadProcessor)
    on_exit(fn -> reset_payload_processor(original) end)
    :ok
  end

  defp setup_throwing_payload_processor do
    original = Application.get_env(:airbrake_client, :payload_processor)
    Application.put_env(:airbrake_client, :payload_processor, ThrowingPayloadProcessor)
    on_exit(fn -> reset_payload_processor(original) end)
    :ok
  end

  defp reset_payload_processor(nil), do: Application.delete_env(:airbrake_client, :payload_processor)
  defp reset_payload_processor(value), do: Application.put_env(:airbrake_client, :payload_processor, value)
end
