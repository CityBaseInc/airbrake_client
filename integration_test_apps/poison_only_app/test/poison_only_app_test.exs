defmodule PoisonOnlyAppTest do
  use ExUnit.Case

  alias Airbrake.Payload

  test "Jason is undefined" do
    # Makes sure conditional compilation for `jason` is skipped without error
    # when `jason` is not a dependency.
    refute Code.ensure_compiled(Jason) == {:module, Jason}
  end

  describe "Poison encoding" do
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
                 "version" => "2.2.0"
               },
               "params" => nil,
               "session" => nil
             } = payload |> Poison.encode!() |> Poison.decode!()
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
                 "version" => "2.2.0"
               },
               "params" => %{"foo" => 55},
               "session" => %{"foo" => 555}
             } = payload |> Poison.encode!() |> Poison.decode!()
    end
  end
end
