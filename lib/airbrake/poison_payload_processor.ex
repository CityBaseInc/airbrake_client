if Code.ensure_loaded?(Poison) do
  defmodule Airbrake.PoisonPayloadProcessor do
    @moduledoc """
    `Airbrake.PayloadProcessor` implementation for the Poison JSON encoder.

    Any `Poison.Encoder` implementations are ignored in the `notice.params`. The
    structs are completely striped away leaving only maps.
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
    Encodes the payload to a JSON string using `Poison.encode!/1`.
    """
    @impl true
    @spec encode!(term()) :: String.t()
    def encode!(payload) do
      Poison.encode!(payload)
    end
  end
end
