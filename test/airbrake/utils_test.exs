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
