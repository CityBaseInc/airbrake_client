defmodule Airbrake.Utils do
  @moduledoc false

  @filtered_value "[FILTERED]"

  # For filtering params and headers.
  def filter(input, nil) do
    input
  end

  def filter(struct, filtered_attributes) when is_struct(struct) do
    struct |> Map.from_struct() |> filter(filtered_attributes)
  end

  def filter(map, filtered_attributes) when is_map(map) do
    Enum.into(map, %{}, &filter_key_value(&1, filtered_attributes))
  end

  def filter(list, filtered_attributes) when is_list(list) do
    Enum.map(list, &filter(&1, filtered_attributes))
  end

  def filter(other, _filtered_attributes) do
    other
  end

  def filter_key_value({k, v}, filtered_attributes) when is_atom(k) do
    filter_key_value({Atom.to_string(k), v}, filtered_attributes)
  end

  def filter_key_value({k, v}, filtered_attributes) do
    if Enum.member?(filtered_attributes, k),
      do: {k, @filtered_value},
      else: {k, filter(v, filtered_attributes)}
  end

  @doc """
  Turns tuples into lists for JSON serialization of Airbrake payloads
  """
  def detuple(%module{} = struct) do
    fields = struct |> Map.from_struct() |> detuple()
    struct(module, fields)
  end

  def detuple(map) when is_map(map) do
    Enum.into(map, %{}, fn {k, v} -> {detuple(k), detuple(v)} end)
  end

  def detuple(list) when is_list(list) do
    Enum.map(list, &detuple/1)
  end

  def detuple(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> detuple()
  end

  def detuple(other) do
    other
  end

  @doc """
  Recursively breaks down structs for JSON serialization of Airbrake payloads
  """
  def destruct(%_module{} = struct) do
    struct |> Map.from_struct() |> destruct()
  end

  def destruct(map) when is_map(map) do
    Enum.into(map, %{}, fn {k, v} -> {destruct(k), destruct(v)} end)
  end

  def destruct(list) when is_list(list) do
    Enum.map(list, &destruct/1)
  end

  def destruct(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> destruct() |> List.to_tuple()
  end

  def destruct(other) do
    other
  end
end
