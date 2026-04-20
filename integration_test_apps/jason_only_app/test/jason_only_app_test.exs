defmodule JasonOnlyAppTest do
  use ExUnit.Case

  alias Airbrake.Config.Validator
  alias Airbrake.Payload

  @airbrake_client_version Application.spec(:airbrake_client, :vsn) |> to_string()

  test "Poison is undefined" do
    # There is no conditional compilation for `poison`... yet.
    refute Code.ensure_compiled(Poison) == {:module, Poison}
  end

  describe "Config.Validator" do
    test "accepts JasonPayloadProcessor" do
      assert :ok = Validator.validate(api_key: "key", project_id: 1, payload_processor: Airbrake.JasonPayloadProcessor)
    end

    test "rejects PoisonPayloadProcessor because Poison is not available" do
      assert {:error, errors} =
               Validator.validate(api_key: "key", project_id: 1, payload_processor: Airbrake.PoisonPayloadProcessor)

      assert ":payload_processor module Airbrake.PoisonPayloadProcessor is not available" in errors
    end
  end

  describe "Jason encoding" do
    test "with minimal options" do
      exception = [
        type: "SomeAwfulError",
        message: "something really bad happened"
      ]

      stacktrace = [
        {Harbour, :cats, [3], []},
        {:timer, :tc, 1, [file: ~c"timer.erl", line: 166]}
      ]

      assert %Payload{} = payload = Payload.new(exception, stacktrace)

      assert %{
               "apiKey" => nil,
               "context" => %{"environment" => _, "hostname" => _},
               "environment" => nil,
               "errors" => [
                 %{
                   "backtrace" => [
                     %{"file" => "unknown", "function" => "Elixir.Harbour.cats(3)", "line" => 0},
                     %{"file" => "timer.erl", "function" => ":timer.tc/1", "line" => 166}
                   ],
                   "message" => "something really bad happened",
                   "type" => "SomeAwfulError"
                 }
               ],
               "notifier" => %{
                 "name" => "Airbrake Client",
                 "url" => "https://github.com/CityBaseInc/airbrake_client",
                 "version" => @airbrake_client_version
               },
               "params" => nil,
               "session" => nil
             } = payload |> Map.from_struct() |> Jason.encode!() |> Jason.decode!()
    end

    test "with all options" do
      exception = [
        type: "SomeAwfulError",
        message: "something really bad happened"
      ]

      stacktrace = [
        {Harbour, :cats, [3], []},
        {:timer, :tc, 1, [file: ~c"timer.erl", line: 166]}
      ]

      context = %{foo: 5}
      params = %{foo: 55}
      session = %{foo: 555}
      env = %{foo: 5555}

      assert %Payload{} =
               payload =
               Payload.new(exception, stacktrace,
                 context: context,
                 params: params,
                 session: session,
                 env: env
               )

      assert %{
               "apiKey" => nil,
               "context" => %{"environment" => _, "hostname" => _, "foo" => 5},
               "environment" => %{"foo" => 5555},
               "errors" => [
                 %{
                   "backtrace" => [
                     %{"file" => "unknown", "function" => "Elixir.Harbour.cats(3)", "line" => 0},
                     %{"file" => "timer.erl", "function" => ":timer.tc/1", "line" => 166}
                   ],
                   "message" => "something really bad happened",
                   "type" => "SomeAwfulError"
                 }
               ],
               "notifier" => %{
                 "name" => "Airbrake Client",
                 "url" => "https://github.com/CityBaseInc/airbrake_client",
                 "version" => @airbrake_client_version
               },
               "params" => %{"foo" => 55},
               "session" => %{"foo" => 555}
             } = payload |> Map.from_struct() |> Jason.encode!() |> Jason.decode!()
    end
  end
end
