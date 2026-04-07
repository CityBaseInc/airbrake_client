defmodule Airbrake.UtilsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Airbrake.Utils

  defmodule Struct do
    defstruct [:baz, :qux]
  end

  describe "filter/2" do
    property "returns input unchanged when attribute list is nil" do
      check all input <- term() do
        assert Utils.filter(input, nil) == input
      end
    end

    test "one big nested structure" do
      input = %{
        "foo" => "bar",
        "baz" => %{"baz" => %{"baz" => %{"quux" => 999}}},
        "qux" => %{
          "x" => 5,
          "y" => 55,
          "z" => 555
        },
        "quuz" => 123,
        "corge" => [1, 2, "three", %{"quux" => 789}],
        "struct" => %Struct{baz: 100, qux: 200}
      }

      filtered_attributes = ["qux", "quux", "quuz"]

      assert Utils.filter(input, filtered_attributes) == %{
               "foo" => "bar",
               # filters deeply...
               "baz" => %{"baz" => %{"baz" => %{"quux" => "[FILTERED]"}}},
               # filters out a whole structure...
               "qux" => "[FILTERED]",
               # filters at the top level...
               "quuz" => "[FILTERED]",
               # filters deeply in a list, repeat attribute...
               "corge" => [1, 2, "three", %{"quux" => "[FILTERED]"}],
               # Filters a struct and casts atom keys to strings...
               "struct" => %{"baz" => 100, "qux" => "[FILTERED]"}
             }
    end

    test "filters a keyword list by key" do
      input = [a: 1, b: 2]
      filtered_attributes = ["a"]

      assert Utils.filter(input, filtered_attributes) == [a: "[FILTERED]", b: 2]
    end

    test "filters an associative list with string keys" do
      input = [{"a", 1}, {"b", 2}]
      filtered_attributes = ["a"]

      assert Utils.filter(input, filtered_attributes) == [{"a", "[FILTERED]"}, {"b", 2}]
    end

    test "filters a keyword list with duplicate keys" do
      input = [a: 1, a: 2, b: 3]
      filtered_attributes = ["a"]

      assert Utils.filter(input, filtered_attributes) == [a: "[FILTERED]", a: "[FILTERED]", b: 3]
    end

    test "recursively filters values in a keyword list" do
      input = [a: 1, b: %{"secret" => "password", "name" => "Alice"}]
      filtered_attributes = ["secret"]

      assert Utils.filter(input, filtered_attributes) == [a: 1, b: %{"secret" => "[FILTERED]", "name" => "Alice"}]
    end

    test "does not filter a non-associative list" do
      input = [1, 2, "three", %{"secret" => "password"}]
      filtered_attributes = ["secret"]

      assert Utils.filter(input, filtered_attributes) == [1, 2, "three", %{"secret" => "[FILTERED]"}]
    end

    test "filters inside a non-string, non-atom key in an associative list" do
      input = [{%{"secret" => "password"}, "value"}]
      filtered_attributes = ["secret"]

      assert Utils.filter(input, filtered_attributes) == [{%{"secret" => "[FILTERED]"}, "value"}]
    end

    test "recursively filters inside a tuple" do
      input = {:ok, %{"secret" => "password", "name" => "Alice"}}
      filtered_attributes = ["secret"]

      assert Utils.filter(input, filtered_attributes) ==
               {:ok, %{"secret" => "[FILTERED]", "name" => "Alice"}}
    end

    test "recursively filters inside a nested tuple" do
      input = {:ok, {:error, %{"secret" => "password", "name" => "Alice"}}}
      filtered_attributes = ["secret"]

      assert Utils.filter(input, filtered_attributes) ==
               {:ok, {:error, %{"secret" => "[FILTERED]", "name" => "Alice"}}}
    end

    test "filters a keyword list nested in a map" do
      input = %{"data" => [a: "secret", b: "public"]}
      filtered_attributes = ["a"]

      assert Utils.filter(input, filtered_attributes) == %{"data" => [a: "[FILTERED]", b: "public"]}
    end
  end

  describe "detuple/1" do
    test "converts tuples to lists" do
      input = %Struct{baz: {1, 2}, qux: {:ok, "foobar"}}
      expected = %Struct{baz: [1, 2], qux: [:ok, "foobar"]}

      assert Utils.detuple(input) == expected
    end

    test "returns de-tupled data when input contains deeply nested tuples" do
      input = %Struct{baz: [1, 2, {3, 4}], qux: %{foo: %{bar: {9, 9, 9, 9}}}}
      expected = %Struct{baz: [1, 2, [3, 4]], qux: %{foo: %{bar: [9, 9, 9, 9]}}}

      assert Utils.detuple(input) == expected
    end

    test "returns detupled data when input is a map with tuples" do
      input = %{baz: {1, 2}, qux: {:ok, "sucess"}}
      expected = %{baz: [1, 2], qux: [:ok, "sucess"]}

      assert Utils.detuple(input) == expected
    end

    test "returns detupled data when input is a list with tuples" do
      input = ["foo", {:ok, "sucess"}]
      expected = ["foo", [:ok, "sucess"]]

      assert Utils.detuple(input) == expected
    end

    test "returns a list when input is nested tuples" do
      input = {:ok, {:error, "something"}}
      expected = [:ok, [:error, "something"]]

      assert Utils.detuple(input) == expected
    end

    property "scalars are returned unchanged" do
      check all scalar <- one_of([integer(), float(), string(:utf8), atom(:alphanumeric), boolean()]) do
        assert Utils.detuple(scalar) == scalar
      end
    end
  end

  describe "destruct/1" do
    test "converts structs to maps" do
      input = %{a: %Struct{baz: 100, qux: 200}, b: "foo", c: %Struct{baz: 1, qux: 2}}
      expected = %{a: %{baz: 100, qux: 200}, b: "foo", c: %{baz: 1, qux: 2}}

      assert Utils.destruct(input) == expected
    end

    test "returns de-structed data when input contains deeply nested structs" do
      input = %Struct{baz: [1, 2, {3, %Struct{baz: "bar"}}], qux: %{foo: %{bar: %Struct{baz: "bar"}, qux: "foo"}}}
      expected = %{baz: [1, 2, {3, %{baz: "bar", qux: nil}}], qux: %{foo: %{bar: %{baz: "bar", qux: nil}, qux: "foo"}}}

      assert Utils.destruct(input) == expected
    end

    test "returns de-structed data when input is a list containing a struct" do
      input = ["foo", %Struct{baz: 100, qux: 200}]
      expected = ["foo", %{baz: 100, qux: 200}]

      assert Utils.destruct(input) == expected
    end

    test "returns the de-structed data when input is a tuple containing a struct" do
      input = {:ok, %Struct{baz: 100, qux: 200}}
      expected = {:ok, %{baz: 100, qux: 200}}

      assert Utils.destruct(input) == expected
    end

    test "returns a map of the original data when input contains nested structs" do
      input = %Struct{baz: 100, qux: %Struct{baz: 100, qux: 200}}
      expected = %{baz: 100, qux: %{baz: 100, qux: 200}}

      assert Utils.destruct(input) == expected
    end

    property "scalars are returned unchanged" do
      check all scalar <- one_of([integer(), float(), string(:utf8), atom(:alphanumeric), boolean()]) do
        assert Utils.destruct(scalar) == scalar
      end
    end
  end
end
