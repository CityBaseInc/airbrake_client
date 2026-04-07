defmodule Airbrake.Utils do
  @moduledoc """
  Utility functions for transforming and filtering payload data.

  These functions are used by the `Airbrake.PayloadProcessor` implementations
  to prepare data for JSON encoding and to filter sensitive values.
  """

  @filtered_value "[FILTERED]"

  @doc """
  Recursively replaces values for keys in `filtered_attributes` with
  `"[FILTERED]"`.

  When `filtered_attributes` is `nil`, the input is returned unchanged.

  `input` is processed recursively:
  * A _struct_ is converted to a map before filtering.
  * A _map_ or _associative list_ or _keyword list_ is processed on two levels:
    * Keys in `filtered_attributes` have their values replaced with
      `"[FILTERED"]"`.
    * Filtering continues recursively on the keys and values.
  * Each elements of a _list_ is recursively filtered.
  * Each element of a _tuple_ is recursively filtered.

  ## Associative (and keyword) lists

  An _associative list_ is a list consisting of 2-element tuples which are
  assumed to be key-value pairs.  You can use functions like `List.keystore/4`,
  `List.keytake/3`, and `List.keyfind/4` on an associative list.  A _keyword
  list_ is an associative list where the keys are all atoms and you can use
  specialized functions from the `Keyword` module.

  This function will filter keys on anything that looks like an associative
  list.

  ## Examples

      iex> Airbrake.Utils.filter(%{"password" => "secret", "name" => "Alice"}, ["password"])
      %{"password" => "[FILTERED]", "name" => "Alice"}

      iex> Airbrake.Utils.filter(%{"password" => "secret"}, nil)
      %{"password" => "secret"}
  """
  def filter(input, filtered_attributes)

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
    if associative_list?(list) do
      Enum.map(list, &filter_assoc_entry(&1, filtered_attributes))
    else
      Enum.map(list, &filter(&1, filtered_attributes))
    end
  end

  def filter(tuple, filtered_attributes) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&filter(&1, filtered_attributes)) |> List.to_tuple()
  end

  def filter(other, _filtered_attributes) do
    other
  end

  @doc """
  Filters a single key-value pair, replacing the value with `"[FILTERED]"` if
  the key is in `filtered_attributes`.

  Atom keys are converted to strings for comparison.

  ## Examples

      iex> Airbrake.Utils.filter_key_value({"password", "secret"}, ["password"])
      {"password", "[FILTERED]"}

      iex> Airbrake.Utils.filter_key_value({:name, "Alice"}, ["password"])
      {"name", "Alice"}
  """
  def filter_key_value({k, v}, filtered_attributes) when is_atom(k) do
    filter_key_value({Atom.to_string(k), v}, filtered_attributes)
  end

  def filter_key_value({k, v}, filtered_attributes) do
    if Enum.member?(filtered_attributes, k),
      do: {k, @filtered_value},
      else: {k, filter(v, filtered_attributes)}
  end

  @doc """
  Recursively converts tuples into lists.

  A struct is temporarily turned into a map, recursively evaluated, and then the
  struct is restored. This may break some typing rules. However, this function
  should be called after `destruct/1`, and so this case should never be
  triggered.

  See also `destruct/1`.

  ## Examples

      iex> Airbrake.Utils.detuple(%{a: {1, 2}})
      %{a: [1, 2]}

      iex> Airbrake.Utils.detuple({:ok, "hello"})
      [:ok, "hello"]
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
  Recursively converts structs into plain maps.

  Recurses into all maps, lists, and tuples, and converts every struct into a
  plain map with `Map.from_struct/1`.

  See also `detuple/1`.

  ## Examples

      iex> Airbrake.Utils.destruct(~D[2024-01-15])
      %{year: 2024, month: 1, day: 15, calendar: Calendar.ISO}

      iex> Airbrake.Utils.destruct(%{a: {1, 2}})
      %{a: {1, 2}}
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

  defp filter_assoc_entry({k, v}, filtered_attributes) when is_atom(k) do
    if Enum.member?(filtered_attributes, Atom.to_string(k)),
      do: {k, @filtered_value},
      else: {k, filter(v, filtered_attributes)}
  end

  defp filter_assoc_entry({k, v}, filtered_attributes) when is_binary(k) do
    if Enum.member?(filtered_attributes, k),
      do: {k, @filtered_value},
      else: {k, filter(v, filtered_attributes)}
  end

  defp filter_assoc_entry({k, v}, filtered_attributes) do
    {filter(k, filtered_attributes), filter(v, filtered_attributes)}
  end

  defp associative_list?([]), do: false
  defp associative_list?(list), do: Enum.all?(list, &match?({_, _}, &1))
end
