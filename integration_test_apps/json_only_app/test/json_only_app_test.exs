defmodule JsonOnlyAppTest do
  use ExUnit.Case

  alias Airbrake.Payload

  @airbrake_client_version Application.spec(:airbrake_client, :vsn) |> to_string()

  test "Jason is undefined" do
    refute Code.ensure_compiled(Jason) == {:module, Jason}
  end

  test "Poison is undefined" do
    refute Code.ensure_compiled(Poison) == {:module, Poison}
  end

  describe "Airbrake.JsonPayloadProcessor encoding" do
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

      # `:json.decode/1` decodes null as :null.
      assert %{
               "apiKey" => :null,
               "context" => %{"environment" => _, "hostname" => _},
               "environment" => :null,
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
               "params" => :null,
               "session" => :null
             } = payload |> Map.from_struct() |> Airbrake.JsonPayloadProcessor.encode!() |> :json.decode()
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
               "apiKey" => :null,
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
             } = payload |> Map.from_struct() |> Airbrake.JsonPayloadProcessor.encode!() |> :json.decode()
    end
  end
end
