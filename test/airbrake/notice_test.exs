defmodule Airbrake.NoticeTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  import Airbrake.Test
  import ExUnit.CaptureIO
  import Mox

  alias Airbrake.{MockHTTPoison, MockPayloadProcessor}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup :stub_mock_config

  @exception [type: "RuntimeError", message: "test error"]
  @stacktrace []

  @fallback_payload ~s({"errors":[{"type":"Airbrake.Notice.Error","message":"airbrake_client failed to process an error notice; see stderr for details"}]})

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
    test "sends a fallback notice instead of crashing" do
      stub(MockPayloadProcessor, :encode!, fn _payload -> raise "encode error" end)
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      {result, output} =
        with_io(:stderr, fn ->
          Airbrake.Notice.post_notice(@exception, @stacktrace, config: MockConfig)
        end)

      assert result == {:error, :initial_post_failed}
      assert output =~ "airbrake_client failed to post a notice for RuntimeError"
      assert output =~ "sending a fallback notice: RuntimeError"
      refute output =~ "test error"
      refute output =~ "encode error"
      assert_receive {:airbrake_report, %{payload: @fallback_payload}}, 500
    end
  end

  describe "post_notice/3 when payload processing throws" do
    test "sends a fallback notice instead of crashing" do
      stub(MockPayloadProcessor, :encode!, fn _payload -> throw(:encode_error) end)
      expect(MockHTTPoison, :post, airbrake_post_mock_fun())

      {result, output} =
        with_io(:stderr, fn ->
          Airbrake.Notice.post_notice(@exception, @stacktrace, config: MockConfig)
        end)

      assert result == {:error, :initial_post_failed}
      assert output =~ "airbrake_client failed to post a notice for RuntimeError"
      assert output =~ "sending a fallback notice: throw"
      refute output =~ "encode_error"
      assert_receive {:airbrake_report, %{payload: @fallback_payload}}, 500
    end
  end

  describe "post_notice/3 when payload processing fails" do
    property "warns with only the types and the arities, whatever the stacktrace" do
      stub(MockHTTPoison, :post, fn _url, _payload, _headers -> {:ok, %HTTPoison.Response{status_code: 201}} end)

      check all secret <- map(string(:alphanumeric, min_length: 1), &"secret-#{&1}"),
                stacktrace <- stacktrace(secret),
                failure <- member_of([:raise, :function_clause, :throw]) do
        stub(MockPayloadProcessor, :encode!, fn payload -> fail_to_encode(failure, payload, secret) end)
        exception = [type: "RuntimeError", message: "boom #{secret}"]

        {result, output} =
          with_io(:stderr, fn -> Airbrake.Notice.post_notice(exception, stacktrace, config: MockConfig) end)

        assert result == {:error, :initial_post_failed}
        assert output =~ "a notice for RuntimeError"
        assert output =~ %{raise: "ArgumentError", function_clause: "FunctionClauseError", throw: "throw"}[failure]
        refute output =~ secret
      end
    end
  end

  describe "post_notice/3 when payload processing raises and fallback also fails" do
    test "returns :error without crashing" do
      stub(MockPayloadProcessor, :encode!, fn _payload -> raise "encode error" end)

      stub(MockHTTPoison, :post, fn _url, _payload, _headers ->
        raise "HTTP adapter error"
      end)

      {result, output} =
        with_io(:stderr, fn ->
          assert Airbrake.Notice.post_notice(@exception, @stacktrace, config: MockConfig)
        end)

      assert result == {:error, :initial_post_failed}
      assert output =~ "airbrake_client failed"
    end
  end

  describe "post_notice/3 when the HTTP adapter raises" do
    test "sends a fallback notice instead of crashing" do
      caller = self()

      MockHTTPoison
      |> expect(:post, fn _url, _payload, _headers ->
        raise "HTTP adapter error"
      end)
      |> expect(:post, fn url, payload, headers ->
        send(caller, {:airbrake_report, %{url: url, payload: payload, headers: headers}})
        {:ok, %HTTPoison.Response{status_code: 201}}
      end)

      {result, output} =
        with_io(:stderr, fn ->
          Airbrake.Notice.post_notice(@exception, @stacktrace, [])
        end)

      assert result == {:error, :initial_post_failed}
      assert output =~ "airbrake_client failed to post a notice for RuntimeError"
      assert output =~ "sending a fallback notice: RuntimeError"
      refute output =~ "HTTP adapter error"
      assert_receive {:airbrake_report, %{payload: @fallback_payload}}, 500
    end
  end

  # The frames of Airbrake.LoggerBackend are strings, and other frames can have args.
  defp stacktrace(secret) do
    list_of(
      one_of([
        constant("(my_app 0.1.0) lib/my_app.ex:12: MyApp.run/1"),
        constant({MyApp, :run, [secret], [file: ~c"lib/my_app.ex", line: 12]}),
        constant({fn -> :ok end, [secret], [file: ~c"lib/my_app.ex", line: 13]})
      ])
    )
  end

  defp fail_to_encode(:raise, _payload, secret), do: raise(ArgumentError, "cannot encode #{secret}")
  defp fail_to_encode(:function_clause, payload, _secret), do: only_nil(payload)
  defp fail_to_encode(:throw, _payload, secret), do: throw({:cannot_encode, secret})

  # The args of the FunctionClauseError frame are the payload, which has the secret in its message.
  defp only_nil(nil), do: ""

  defp stub_mock_config(_context) do
    stub(MockConfig, :context_environment, fn -> "test" end)
    stub(MockConfig, :hostname, fn -> "test-host" end)
    stub(MockConfig, :get, fn _key -> nil end)
    stub(MockConfig, :get, fn _key, default -> default end)
    stub(MockConfig, :payload_processor, fn -> MockPayloadProcessor end)
    stub(MockPayloadProcessor, :process_params, fn params, _opts -> params end)
    :ok
  end
end
