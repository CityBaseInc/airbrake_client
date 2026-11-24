if Code.ensure_loaded?(:json) do
  defmodule Airbrake.JsonPayloadProcessor do
    @moduledoc """
    `Airbrake.PayloadProcessor` implementation for Elixir's `JSON` module, or
    for Erlang's `:json` module with Elixir 1.17.
    """

    @behaviour Airbrake.PayloadProcessor

    @doc """
    Destructures structs, filters sensitive keys, and converts tuples to lists.
    """
    @impl true
    @spec process_params(term(), keyword()) :: term()
    def process_params(params, opts) do
      filter_params = Keyword.get(opts, :filtered_attributes, [])

      params
      |> Airbrake.Utils.destruct()
      |> Airbrake.Utils.filter(filter_params)
      |> Airbrake.Utils.detuple()
    end

    @doc """
    Delegates to `Airbrake.Utils.filter/2`.
    """
    @impl true
    @spec process_headers(term(), keyword()) :: term()
    def process_headers(headers, opts) do
      filtered_attributes = Keyword.get(opts, :filtered_attributes, [])
      Airbrake.Utils.filter(headers, filtered_attributes)
    end

    @doc """
    Encodes the payload to a JSON string using `JSON.encode!/1`.

    Elixir 1.17 does not have `JSON`, so this uses `:json.encode/2` instead,
    with `nil` encoded as `null`.
    """
    @impl true
    @spec encode!(term()) :: String.t()
    if Code.ensure_loaded?(JSON) do
      def encode!(payload), do: JSON.encode!(payload)
    else
      def encode!(payload), do: erlang_json_encode!(payload)
    end

    # :json.encode/1 encodes the atom nil as the string "nil".
    @doc false
    @spec erlang_json_encode!(term()) :: String.t()
    def erlang_json_encode!(payload) do
      payload |> :json.encode(&encode_value/2) |> IO.iodata_to_binary()
    end

    defp encode_value(nil, _encoder), do: "null"
    defp encode_value(value, encoder), do: :json.encode_value(value, encoder)
  end
end
