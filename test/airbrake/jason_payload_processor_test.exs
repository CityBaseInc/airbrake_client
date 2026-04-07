defmodule Airbrake.JasonPayloadProcessorTest do
  use ExUnit.Case, async: true

  alias Airbrake.JasonPayloadProcessor
  alias Airbrake.TestSupport.{Boss, Employee, Team}

  describe "process_params/2" do
    test "destructures structs, filters, and converts tuples to lists" do
      assert JasonPayloadProcessor.process_params(
               %Team{
                 members: [
                   %Boss{name: "Diana", hired_on: {2020, 1, 15}},
                   %Boss{name: "Eve", hired_on: ~D[2021-03-10]},
                   %Employee{name: "Alice", age: 30}
                 ]
               },
               []
             ) == %{
               "members" => [
                 %{"name" => "Diana", "hired_on" => [2020, 1, 15]},
                 %{
                   "name" => "Eve",
                   "hired_on" => %{"year" => 2021, "month" => 3, "day" => 10, "calendar" => Calendar.ISO}
                 },
                 %{"name" => "Alice", "age" => 30}
               ]
             }
    end

    test "filters sensitive keys" do
      assert JasonPayloadProcessor.process_params(
               %{"password" => "secret", "name" => "Alice"},
               filtered_attributes: ["password"]
             ) == %{"password" => "[FILTERED]", "name" => "Alice"}
    end
  end

  describe "process_headers/2" do
    test "filters matching keys" do
      assert JasonPayloadProcessor.process_headers(
               %{"authorization" => "Bearer token", "content-type" => "application/json"},
               filtered_attributes: ["authorization"]
             ) == %{"authorization" => "[FILTERED]", "content-type" => "application/json"}
    end
  end

  describe "encode!/1" do
    test "encodes a map to JSON" do
      assert JasonPayloadProcessor.encode!(%{"key" => "value"}) == ~s/{"key":"value"}/
    end
  end
end
