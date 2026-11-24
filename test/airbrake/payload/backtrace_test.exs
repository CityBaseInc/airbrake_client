defmodule Airbrake.Payload.BacktraceTests do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Airbrake.Payload.Backtrace

  describe "from_stacktrace/1" do
    test "turns a whole stacktrace into a backtrace" do
      # This stacktrace is a hodgepodge of stacktrace entries.
      stacktrace = [
        {Ecto.Adapters.SQL, :raise_sql_call_error, 1,
         [file: ~c"lib/ecto/adapters/sql.ex", line: 1078, error_info: %{module: Exception}]},
        {Harbour, :cats, [3], []},
        {:erl_eval, :do_apply, 6, [file: ~c"erl_eval.erl", line: 680]},
        {:erl_eval, :try_clauses, 8, [file: ~c"erl_eval.erl", line: 914]},
        {:elixir, :recur_eval, 3, [file: ~c"src/elixir.erl", line: 280]},
        {:elixir, :eval_forms, 3, [file: ~c"src/elixir.erl", line: 265]},
        {IEx.Evaluator, :handle_eval, 5, [file: ~c"lib/iex/evaluator.ex", line: 261]},
        {IEx.Evaluator, :do_eval, 3, [file: ~c"lib/iex/evaluator.ex", line: 242]},
        {IEx.Evaluator, :eval, 3, [file: ~c"lib/iex/evaluator.ex", line: 220]}
      ]

      assert Backtrace.from_stacktrace(stacktrace) == [
               %{
                 file: "lib/ecto/adapters/sql.ex",
                 function: "Elixir.Ecto.Adapters.SQL.raise_sql_call_error/1",
                 line: 1078
               },
               %{file: "unknown", function: "Elixir.Harbour.cats(3)", line: 0},
               %{file: "erl_eval.erl", function: ":erl_eval.do_apply/6", line: 680},
               %{file: "erl_eval.erl", function: ":erl_eval.try_clauses/8", line: 914},
               %{file: "src/elixir.erl", function: ":elixir.recur_eval/3", line: 280},
               %{file: "src/elixir.erl", function: ":elixir.eval_forms/3", line: 265},
               %{file: "lib/iex/evaluator.ex", function: "Elixir.IEx.Evaluator.handle_eval/5", line: 261},
               %{file: "lib/iex/evaluator.ex", function: "Elixir.IEx.Evaluator.do_eval/3", line: 242},
               %{file: "lib/iex/evaluator.ex", function: "Elixir.IEx.Evaluator.eval/3", line: 220}
             ]
    end
  end

  describe "from_stacktrace_entry/1" do
    property "formats an entry without a file or line" do
      check all module <- atom(:alias),
                function <- atom(:alphanumeric),
                args <- list_of(integer()) do
        entry = {module, function, args, []}

        assert Backtrace.from_stacktrace_entry(entry) == %{
                 file: "unknown",
                 function: "#{module}.#{function}(#{Enum.join(args, ", ")})",
                 line: 0
               }
      end
    end

    property "formats an entry with file and line options" do
      check all module <- atom(:alias),
                function <- atom(:alphanumeric),
                arity <- positive_integer(),
                file <- string(:ascii),
                line <- positive_integer(),
                generic_extras <- keyword_of(string(:ascii)) do
        entry_file = String.to_charlist(file)
        entry = {module, function, arity, [file: entry_file, line: line] ++ generic_extras}

        assert Backtrace.from_stacktrace_entry(entry) == %{
                 file: file,
                 function: "#{module}.#{function}/#{arity}",
                 line: line
               }
      end
    end

    property "formats an anonymous function entry with file and line options" do
      fun = fn -> :ok end

      check all arity_or_args <- one_of([positive_integer(), list_of(integer())]),
                file <- string(:ascii),
                line <- positive_integer() do
        entry = {fun, arity_or_args, [file: String.to_charlist(file), line: line]}

        formatted_args =
          if is_integer(arity_or_args), do: "/#{arity_or_args}", else: "(#{Enum.join(arity_or_args, ", ")})"

        assert Backtrace.from_stacktrace_entry(entry) == %{
                 file: file,
                 function: "#{inspect(fun)}#{formatted_args}",
                 line: line
               }
      end
    end

    test "formats an anonymous function entry without a file or line" do
      fun = fn -> :ok end

      assert Backtrace.from_stacktrace_entry({fun, 0, []}) == %{
               file: "unknown",
               function: "#{inspect(fun)}/0",
               line: 0
             }
    end

    property "formats a string entry with app, file, and function information" do
      check all app <- string(:alphanumeric, min_length: 1),
                file <- string(:alphanumeric, min_length: 1),
                line <- integer(1..1000),
                function <- string(:alphanumeric, min_length: 1) do
        entry = "(#{app}) #{file}:#{line}: #{function}"

        assert Backtrace.from_stacktrace_entry(entry) == %{
                 file: file,
                 line: line,
                 function: "(#{app}) #{function}"
               }
      end
    end

    property "formats a string entry with file and function information but no app" do
      check all file <- string(:alphanumeric, min_length: 1),
                line <- integer(1..1000),
                function <- string(:alphanumeric, min_length: 1) do
        entry = "#{file}:#{line}: #{function}"

        assert Backtrace.from_stacktrace_entry(entry) == %{
                 file: file,
                 line: line,
                 function: function
               }
      end
    end

    property "format a string entry that can't be parsed" do
      # without a colon, there is no "file:line:" to parse
      check all entry <- filter(string(:ascii), &(not String.contains?(&1, ":"))) do
        assert Backtrace.from_stacktrace_entry(entry) == %{
                 file: "unknown",
                 line: 0,
                 function: entry
               }
      end
    end
  end

  describe "format_module/1" do
    test "formats an Elixir module, adding Elixir prefix" do
      assert Backtrace.format_module(Airbrake.Payload) == "Elixir.Airbrake.Payload"
    end

    test "formats an erlang module, prepending a colon" do
      assert Backtrace.format_module(:timer) == ":timer"
    end
  end
end
