if Code.ensure_loaded?(:json) do
  defmodule Airbrake.JsonPayloadProcessor do
    @moduledoc """
    `Airbrake.PayloadProcessor` implementation for Erlang's `:json` encoder.
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
    Encodes the payload to a JSON string using `:json.encode/1`.
    """
    @impl true
    @spec encode!(term()) :: String.t()
    def encode!(payload) do
      payload |> :json.encode() |> IO.iodata_to_binary()
    end
  end
end
