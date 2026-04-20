defmodule Airbrake.PayloadProcessor do
  @moduledoc """
  Behaviour for encoder-specific payload operations.

  * `process_params/2` is used to process the `params` attribute in an Airbrake
    notice. It should do two things: filter out sensitive data, and transform
    the data for JSON encoding with `encode!/1`.
  * `process_headers/2` is used to filter sensitive data from the headers
    included in the `notice.environment` attribute of an Airbrake notice.
  * `encode!/1` is used to encode the entire payload as a JSON string.

  Three implementations are provided:
  * `Airbrake.JasonPayloadProcessor` for the [`jason`
    library](https://hex.pm/packages/jason).
  * `Airbrake.JsonPayloadProcessor` for [`:json` provided in Erlang
    27+](https://www.erlang.org/doc/apps/stdlib/json.html).
  * `Airbrake.PoisonPayloadProcessor` for the [`poison`
    library](https://hex.pm/packages/poison).

  `airbrake_client` provides functions to make implementing these callbacks
  easier. See the example below.

  ## Writing your own

  If the provided implementations don't suit your needs, you can write your own
  module and set it as the `:payload_processor` in your config.

  ```elixir
  defmodule MyApp.PayloadProcessor do
    @behaviour Airbrake.PayloadProcessor

    @impl true
    def process_params(params, opts) do
      filtered_attributes = Keyword.get(opts, :filtered_attributes, [])

      params
      |> Airbrake.Utils.destruct()
      |> Airbrake.Utils.filter(filtered_attributes)
      |> Airbrake.Utils.detuple()
    end

    @impl true
    def process_headers(headers, opts) do
      filtered_attributes = Keyword.get(opts, :filtered_attributes, [])
      Airbrake.Utils.filter(headers, filtered_attributes)
    end

    @impl true
    def encode!(payload) do
      Jason.encode!(payload)
    end
  end
  ```

  Then in your config:

  ```elixir
  config :airbrake_client,
    payload_processor: MyApp.PayloadProcessor
  ```
  """

  @doc """
  Processes the params payload: transforms Elixir terms into JSON-encodable
  forms and filters sensitive data.

  The provided implementations destructure structs, filter sensitive keys,
  and convert tuples to lists.

  ## Options

    * `:filtered_attributes` - list of attribute name strings to replace with `"[FILTERED]"`
  """
  @callback process_params(params :: term(), opts :: keyword()) :: term()

  @doc """
  Filters sensitive header values.

  The provided implementations all delegate to `Airbrake.Utils.filter/2`.

  ## Options

    * `:filtered_attributes` - list of attribute name strings to replace with `"[FILTERED]"`
  """
  @callback process_headers(headers :: term(), opts :: keyword()) :: term()

  @doc """
  Encodes the given payload to a JSON string.

  You can use any function that encodes your data to a string.  Airbrake expects
  it to be a JSON string.
  """
  @callback encode!(payload :: term()) :: String.t()
end
