defmodule Airbrake.Notice do
  @moduledoc false

  alias Airbrake.{Config, Payload}

  @request_headers [{"Content-Type", "application/json"}]
  @default_host "https://api.airbrake.io"
  @default_http_adapter HTTPoison

  @spec post_notice([type: String.t(), message: String.t()], Exception.stacktrace(), keyword()) :: term()
  def post_notice(exception, stacktrace, options) do
    unless ignore?(exception) do
      enhanced_options = build_options(options)
      payload = Payload.new(exception, stacktrace, enhanced_options)
      json_payload = json_encode(payload, options)
      http_adapter().post(notify_url(), json_payload, @request_headers)
    end
  rescue
    e ->
      IO.warn("airbrake_client failed to process an error notice, sending fallback")
      IO.warn("original error: #{string_or_inspect(exception)}", stacktrace)
      IO.warn("post notice error: #{string_or_inspect(e)}")
      post_fallback_notice()
      {:error, :initial_post_failed}
  catch
    kind, value ->
      IO.warn("airbrake_client failed to process an error notice, sending fallback")
      IO.warn("original error: #{string_or_inspect(exception)}", stacktrace)
      IO.warn("post notice error: #{string_or_inspect(kind)}: #{string_or_inspect(value)}")
      post_fallback_notice()
      {:error, :initial_post_failed}
  end

  defp post_fallback_notice do
    json =
      ~s({"errors":[{"type":"Airbrake.Notice.Error","message":"airbrake_client failed to process an error notice; see stderr for details"}]})

    http_adapter().post(notify_url(), json, @request_headers)
  rescue
    e ->
      IO.warn("airbrake_client failed to send fallback notice")
      IO.warn("error: #{string_or_inspect(e)}")
      {:error, :fallback_post_failed}
  catch
    kind, value ->
      IO.warn("airbrake_client failed to send fallback notice")
      IO.warn("error: #{string_or_inspect(kind)}: #{string_or_inspect(value)}")
      {:error, :fallback_post_failed}
  end

  defp string_or_inspect(str) when is_binary(str), do: str
  defp string_or_inspect(other), do: inspect(other)

  @spec json_encode(Payload.t(), keyword()) :: String.t()
  def json_encode(%Payload{} = payload, opts \\ []) do
    config = Keyword.get(opts, :config, Config)
    processor = config.payload_processor()

    payload
    |> Map.from_struct()
    |> processor.encode!()
  end

  defp build_options(current_options) do
    case Config.get(:options) do
      {mod, fun, 1} ->
        apply(mod, fun, [current_options])

      shared_options when is_list(shared_options) ->
        Keyword.merge(shared_options, current_options)

      _ ->
        current_options
    end
  end

  defp ignore?(type: type, message: message) do
    ignore?(Config.get(:ignore), type, message)
  end

  defp ignore?(nil, _type, _message), do: false
  defp ignore?(:all, _type, _message), do: true
  defp ignore?(fun, type, message) when is_function(fun), do: fun.(type, message)
  defp ignore?(types, type, _message), do: MapSet.member?(types, type)

  defp http_adapter do
    :airbrake_client
    |> Application.get_env(:private, [])
    |> Keyword.get(:http_adapter, @default_http_adapter)
  end

  defp notify_url do
    host = Config.get(:host, @default_host)
    project_id = Config.get(:project_id)
    api_key = Config.get(:api_key)

    Path.join([host, "api/v3/projects", to_string(project_id), "notices?key=#{api_key}"])
  end
end
