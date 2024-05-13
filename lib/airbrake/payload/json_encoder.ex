defmodule Airbrake.JSONEncoder do
  @moduledoc false

  @json_encoder Application.compile_env(:airbrake_client, :json_encoder, Poison)

  def encoder do
    @json_encoder
  end

  defmacro encode!(payload) do
    quote do
      unquote(@json_encoder).encode!(unquote(payload))
    end
  end
end
