defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success test"}}
    def handler(%{"value" => "failure"}, _context), do: {:error, "failure test"}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test beam"

    sequence do
      step(:test, TestPrism, %{})
    end
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an Ollama function" do
      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              }
            }
          }
        )

      function = Ollama.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: "object",
                   properties: %{
                     "value" => %{
                       type: "string",
                       description: "Test value"
                     }
                   }
                 }
               }
             } = function
    end

    test "converts a prism to an Ollama function" do
      prism = TestPrism.view()

      function = Ollama.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_OllamaTest_TestPrism",
                 description: "A test prism",
                 parameters: %{
                   type: :object,
                   properties: %{
                     value: %{
                       type: :string
                     }
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct API call with tools via OpenAI-compatible route" do
      config = %{
        endpoint: "http://localhost:11434",
        model: "llama3"
      }

      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              }
            }
          }
        )

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "llama3"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]
        assert [tool] = decoded_body["tools"]
        assert tool["function"]["name"] == "TestBeam"

        Req.Test.json(conn, %{
          "id" => "ollama-chat-123",
          "model" => "llama3",
          "created" => 1700000000,
          "choices" => [
            %{
              "message" => %{
                "content" => ~s({"result": "Test response"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 20,
            "total_tokens" => 30
          }
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "Test response"},
                  finish_reason: "stop",
                  model: "llama3",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{
                  id: "ollama-chat-123",
                  usage: %{"prompt_tokens" => 10, "completion_tokens" => 20, "total_tokens" => 30}
                }
              }} = Ollama.call("test prompt", [beam], config)
    end

    test "handles tool call responses with successful tool call (prism)" do
      config = %{
        endpoint: "http://localhost:11434",
        model: "llama3"
      }

      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3",
          "choices" => [
            %{
              "message" => %{
                "tool_calls" => [
                  %{
                    "type" => "function",
                    "function" => %{
                      "name" => "#{TestPrism}",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ]
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: nil,
                  finish_reason: "tool_calls",
                  model: "llama3",
                  tool_calls: [
                    %{
                      "function" => %{
                        "arguments" => ~s({"value": "success"}),
                        "name" => "Elixir.Lux.LLM.OllamaTest.TestPrism"
                      },
                      "type" => "function"
                    }
                  ],
                  tool_calls_results: [%{result: "success test"}]
                }
              }} = Ollama.call("test prompt", [TestPrism], config)
    end
  end

  describe "Model Management Actions" do
    test "list_models/1 hits tags endpoint" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/tags"

        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3:latest", "size" => 4661224618}
          ]
        })
      end)

      assert {:ok, %{"models" => [%{"name" => "llama3:latest"}]}} = Ollama.list_models(%{endpoint: "http://localhost:11434"})
    end

    test "pull_model/2 hits pull endpoint" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert %{"name" => "llama3", "stream" => false} = Jason.decode!(body)

        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, %{"status" => "success"}} = Ollama.pull_model("llama3", %{endpoint: "http://localhost:11434"})
    end

    test "delete_model/2 hits delete endpoint" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert %{"name" => "llama3"} = Jason.decode!(body)

        Req.Test.json(conn, %{"status" => "deleted"})
      end)

      assert {:ok, %{"status" => "deleted"}} = Ollama.delete_model("llama3", %{endpoint: "http://localhost:11434"})
    end

    test "show_model/2 hits show endpoint" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/show"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert %{"name" => "llama3"} = Jason.decode!(body)

        Req.Test.json(conn, %{"license" => "MIT", "modelfile" => "FROM llama3"})
      end)

      assert {:ok, %{"license" => "MIT", "modelfile" => "FROM llama3"}} = Ollama.show_model("llama3", %{endpoint: "http://localhost:11434"})
    end
  end
end
