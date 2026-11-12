defmodule Airbrake.Payload.Backtrace do
  @moduledoc false

  @spec from_stacktrace(Exception.stacktrace() | [String.t()]) :: [map()]
  def from_stacktrace(stacktrace),
    do: Enum.map(stacktrace, &from_stacktrace_entry/1)

  @spec from_stacktrace_entry(tuple() | String.t()) :: map()
  def from_stacktrace_entry({module, function, args, opts}) do
    from_location("#{format_module(module)}.#{function}#{format_args(args)}", opts)
  end

  def from_stacktrace_entry({fun, args, opts}) when is_function(fun) do
    from_location("#{inspect(fun)}#{format_args(args)}", opts)
  end

  def from_stacktrace_entry(string) when is_binary(string) do
    info = Regex.named_captures(~r/\A(?:(?<app>\(.*?\))\s*)?(?<file>.*?):(?<line>\d+):\s*(?<function>.*)\z/, string)

    if info do
      %{
        file: info["file"],
        line: String.to_integer(info["line"]),
        function: format_function(info["app"], info["function"])
      }
    else
      %{
        file: "unknown",
        line: 0,
        function: string
      }
    end
  end

  @spec format_module(module()) :: String.t()
  def format_module(module) do
    string = Atom.to_string(module)
    if String.starts_with?(string, "Elixir."), do: string, else: ":#{string}"
  end

  defp from_location(function, opts) do
    %{
      file: opts |> Keyword.get(:file, ~c"unknown") |> List.to_string(),
      line: Keyword.get(opts, :line, 0),
      function: function
    }
  end

  defp format_function("", function), do: function
  defp format_function(app, function), do: "#{app} #{function}"

  defp format_args(args) when is_integer(args) do
    "/#{args}"
  end

  defp format_args(args) when is_list(args) do
    "(#{Enum.map_join(args, ", ", &inspect(&1))})"
  end
end
