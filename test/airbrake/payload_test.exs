defmodule Airbrake.PayloadTest do
  use ExUnit.Case
  alias Airbrake.Payload

  @exception %UndefinedFunctionError{
    arity: 1,
    function: :cats,
    message: nil,
    module: Harbour,
    reason: nil
  }

  @stacktrace [
    {Harbour, :cats, [3], []},
    {:timer, :tc, 1, [file: ~c"timer.erl", line: 166]}
  ]

  describe "new/2 and new/3" do
    test "generates report with a REAL exception" do
      {exception, stacktrace} =
        try do
          Harbour.cats(3)
        rescue
          exception -> {exception, __STACKTRACE__}
        end

      # This is probably VERY fragile, so if it sees a lot of churn, we can
      # break it down into smaller tests.
      assert %Payload{
               apiKey: nil,
               context: %{environment: _, hostname: _},
               errors: [
                 %{
                   backtrace: [
                     %{file: "unknown", function: "Elixir.Harbour.cats(3)", line: 0},
                     %{
                       file: "test/airbrake/payload_test.exs",
                       function:
                         "Elixir.Airbrake.PayloadTest.test new/2 and new/3 generates report with a REAL exception/1",
                       line: _
                     }
                     | _rest_of_backtrace
                   ],
                   message: "function Harbour.cats/1 is undefined (module Harbour is not available)",
                   type: "UndefinedFunctionError"
                 }
               ],
               notifier: %{
                 name: "Airbrake Client",
                 url: "https://github.com/CityBaseInc/airbrake_client",
                 version: "2.2.1"
               }
             } = Payload.new(exception, stacktrace)
    end

    test "reports the error class of an exception" do
      assert %Payload{errors: [error]} = Payload.new(@exception, @stacktrace)
      assert "UndefinedFunctionError" == error.type
    end

    test "reports the type when explicitly specified" do
      exception_keyword_list = [
        type: "SomeAwfulError",
        message: "something really bad happened"
      ]

      assert %Payload{errors: [%{type: "SomeAwfulError"}]} = Payload.new(exception_keyword_list, @stacktrace)
    end

    test "reports the error message from an exception" do
      assert %Payload{errors: [error]} = Payload.new(@exception, @stacktrace)

      assert "function Harbour.cats/1 is undefined (module Harbour is not available)" ==
               error.message
    end

    test "reports the error message when explicitly specified" do
      exception_keyword_list = [
        type: "SomeAwfulError",
        message: "something really bad happened"
      ]

      assert %Payload{errors: [%{message: "something really bad happened"}]} =
               Payload.new(exception_keyword_list, @stacktrace)
    end

    # NOTE: turning a stacktrace into a backtrace is tested in more depth with
    # Airbrake.Payload.Backtrace
    test "it generates correct stacktraces when the current file was a script" do
      stacktrace = [
        {Harbour, :cats, [3], []},
        {:timer, :tc, 1, [file: ~c"timer.erl", line: 166]}
      ]

      assert %Payload{errors: [error]} = Payload.new(@exception, stacktrace)

      assert [
               %{file: "unknown", function: "Elixir.Harbour.cats(3)", line: 0},
               %{file: "timer.erl", function: ":timer.tc/1", line: 166}
             ] = error.backtrace
    end

    test "reports the notifier" do
      assert %Payload{
               notifier: %{
                 name: "Airbrake Client",
                 url: "https://github.com/CityBaseInc/airbrake_client",
                 version: "2.2.1"
               }
             } = Payload.new(@exception, @stacktrace)
    end

    test "sets a default context" do
      assert %Payload{context: context} = Payload.new(@exception, @stacktrace)
      assert %{environment: _, hostname: _} = context
    end

    test "sets the context when given" do
      context = %{msg: "Potato#cake"}
      assert %Payload{context: context} = Payload.new(@exception, @stacktrace, context: context)
      assert "Potato#cake" == context.msg
    end

    test "sets environment when given :env" do
      env = %{foo: 5, bar: "qux"}
      assert %Payload{environment: ^env} = Payload.new(@exception, @stacktrace, env: env)
    end

    test "it filters sensitive headers in the environment" do
      Application.put_env(:airbrake_client, :filter_headers, ["authorization"])

      env = %{
        "headers" => %{"authorization" => "Bearer JWT", "x" => "y"},
        "httpMethod" => "POST"
      }

      assert %Payload{
               environment: %{
                 "headers" => %{"authorization" => "[FILTERED]", "x" => "y"},
                 "httpMethod" => "POST"
               }
             } = Payload.new(@exception, @stacktrace, env: env)

      Application.delete_env(:airbrake_client, :filter_headers)
    end

    test "sets params when given" do
      params = %{foo: 55, bar: "qux"}

      assert %Payload{
               params: %{"foo" => 55, "bar" => "qux"}
             } = Payload.new(@exception, @stacktrace, params: params)
    end

    test "filters sensitive params" do
      # "password" is filtered out in `config/test.exs`
      # Filtering is tested in more depth for `Airbrake.Payload.Builder`.
      params = %{"password" => "top_secret", "x" => "y"}

      assert %Payload{params: %{"password" => "[FILTERED]", "x" => "y"}} =
               Payload.new(@exception, @stacktrace, params: params)
    end

    test "sets session when given" do
      session = %{foo: 555, bar: "qux"}
      assert %Payload{session: ^session} = Payload.new(@exception, @stacktrace, session: session)
    end
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
                 "version" => "2.2.1"
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
               Payload.new(exception, stacktrace, context: context, params: params, session: session, env: env)

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
                 "version" => "2.2.1"
               },
               "params" => %{"foo" => 55},
               "session" => %{"foo" => 555}
             } = payload |> Poison.encode!() |> Poison.decode!()
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
                 "version" => "2.2.1"
               },
               "params" => nil,
               "session" => nil
             } = payload |> Jason.encode!() |> Jason.decode!()
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
               Payload.new(exception, stacktrace, context: context, params: params, session: session, env: env)

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
                 "version" => "2.2.1"
               },
               "params" => %{"foo" => 55},
               "session" => %{"foo" => 555}
             } = payload |> Jason.encode!() |> Jason.decode!()
    end
  end
end
