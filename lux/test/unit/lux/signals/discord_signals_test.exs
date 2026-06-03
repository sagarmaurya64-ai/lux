defmodule Lux.Signals.DiscordSignalsTest do
  # Use the same UnitAPICase as existing unit tests
  use UnitAPICase, async: true

  alias Lux.Signals.DiscordMessage
  alias Lux.Signals.DiscordInteraction
  alias Lux.Signals.DiscordPresence
  alias Lux.Signal

  # Define a dummy agent for testing the signal pipeline
  defmodule TestDiscordAgent do
    use Lux.Agent,
      name: "test_discord_agent",
      accepts_signals: [Lux.Schemas.DiscordMessageSchema],
      signal_handlers: [
        {Lux.Schemas.DiscordMessageSchema, {__MODULE__, :handle_discord_message}}
      ]

    def init(opts), do: {:ok, opts}

    def handle_discord_message(signal, agent) do
      if test_process = agent.template_opts[:test_process] do
        send(test_process, {:handled_signal, signal})
      end
      {:ok, agent}
    end
  end

  describe "DiscordMessageSignal" do
    test "from_discord/1 converts a valid raw message successfully" do
      raw_payload = %{
        "id" => "112233445566",
        "content" => "Hello standard agent! 🚀",
        "channel_id" => "123456789012345678",
        "guild_id" => "987654321098765432",
        "author" => %{
          "id" => "112233445566778899",
          "username" => "test_user",
          "bot" => false
        },
        "attachments" => [
          %{
            "id" => "556677889900112233",
            "filename" => "log.txt",
            "url" => "https://discord.com/attachments/log.txt"
          }
        ],
        "embeds" => [
          %{
            "title" => "Embed title",
            "description" => "Embed description"
          }
        ],
        "timestamp" => "2026-06-02T16:00:00Z",
        "type" => 0,
        "flags" => 64,
        "mentions" => [
          %{"id" => "223344", "username" => "mentioned_user"}
        ],
        "referenced_message" => %{
          "id" => "88888",
          "content" => "Replying to this",
          "channel_id" => "123456789012345678",
          "author" => %{"id" => "99999", "username" => "original_author"}
        }
      }

      assert {:ok, %Signal{} = signal} = DiscordMessage.from_discord(raw_payload)
      assert signal.sender == "112233445566778899"
      assert signal.topic == "discord:message:123456789012345678"
      assert signal.schema_id == Lux.Schemas.DiscordMessageSchema

      payload = signal.payload
      assert payload.id == "112233445566"
      assert payload.content == "Hello standard agent! 🚀"
      assert payload.channel_id == "123456789012345678"
      assert payload.author.username == "test_user"
      assert [att] = payload.attachments
      assert att.filename == "log.txt"
      assert payload.type == 0
      assert payload.flags == 64
      assert [mention] = payload.mentions
      assert mention.username == "mentioned_user"
      assert payload.referenced_message.content == "Replying to this"
    end

    test "from_discord/1 supports atom-keyed maps" do
      raw_payload = %{
        content: "Atom keys!",
        channel_id: "1234",
        author: %{
          id: "5678",
          username: "atom_user"
        }
      }

      assert {:ok, %Signal{} = signal} = DiscordMessage.from_discord(raw_payload)
      assert signal.payload.content == "Atom keys!"
      assert signal.payload.author.username == "atom_user"
    end

    test "from_discord/1 fails on missing required fields" do
      # Missing content, channel_id, or author
      raw_payload = %{
        "channel_id" => "123456789012345678",
        "author" => %{
          "id" => "112233445566778899",
          "username" => "test_user"
        }
      }

      assert {:error, _errors} = DiscordMessage.from_discord(raw_payload)
    end

    test "from_discord/1 defensively handles malformed inputs" do
      # Non-map input
      assert {:error, [%{"message" => "Expected payload to be a map"}]} = DiscordMessage.from_discord("invalid")

      # Malformed list for attachments
      raw_payload = %{
        "content" => "Malformed attachments",
        "channel_id" => "1234",
        "author" => %{"id" => "5678", "username" => "user"},
        "attachments" => "should_be_a_list"
      }
      assert {:ok, %Signal{} = signal} = DiscordMessage.from_discord(raw_payload)
      assert signal.payload.attachments == []
    end

    test "from_discord/1 fails when required content is nil" do
      raw_payload = %{
        "content" => nil,
        "channel_id" => "123456789012345678",
        "author" => %{
          "id" => "112233445566778899",
          "username" => "test_user"
        }
      }
      assert {:error, _errors} = DiscordMessage.from_discord(raw_payload)
    end

    test "from_discord/1 handles list of non-map attachments gracefully" do
      raw_payload = %{
        "content" => "List containing non-maps",
        "channel_id" => "1234",
        "author" => %{"id" => "5678", "username" => "user"},
        "attachments" => ["not_a_map", %{"id" => "1", "filename" => "x.png", "url" => "http://x.png"}]
      }
      assert {:ok, %Signal{} = signal} = DiscordMessage.from_discord(raw_payload)
      assert [%{id: "1", filename: "x.png", url: "http://x.png"}] = signal.payload.attachments
    end

    test "to_discord/1 converts a validated signal back to raw Discord format with audit fields" do
      raw_payload = %{
        "id" => "1122",
        "content" => "Converting back!",
        "channel_id" => "12345",
        "author" => %{
          "id" => "6789",
          "username" => "convert_user",
          "bot" => true
        },
        "type" => 19,
        "flags" => 0,
        "mentions" => [%{"id" => "444", "username" => "mentioned"}],
        "referenced_message" => %{
          "id" => "999",
          "content" => "Original",
          "channel_id" => "12345",
          "author" => %{"id" => "123", "username" => "other"}
        }
      }

      {:ok, signal} = DiscordMessage.from_discord(raw_payload)
      serialized = DiscordMessage.to_discord(signal)

      assert serialized["id"] == "1122"
      assert serialized["content"] == "Converting back!"
      assert serialized["channel_id"] == "12345"
      assert serialized["author"]["username"] == "convert_user"
      assert serialized["author"]["bot"] == true
      assert serialized["type"] == 19
      assert [m] = serialized["mentions"]
      assert m["username"] == "mentioned"
      assert serialized["referenced_message"]["content"] == "Original"
    end
  end

  describe "DiscordInteractionSignal" do
    test "from_discord/1 converts a valid raw interaction command successfully" do
      raw_payload = %{
        "id" => "11111111",
        "type" => 2, # APPLICATION_COMMAND
        "token" => "abc_interaction_token",
        "guild_id" => "22222222",
        "channel_id" => "33333333",
        "application_id" => "998877",
        "version" => 1,
        "locale" => "en-US",
        "member" => %{
          "user" => %{
            "id" => "44444444",
            "username" => "commander"
          }
        },
        "data" => %{
          "name" => "verify_bounty",
          "options" => [%{"name" => "target", "type" => 3, "value" => "lux"}]
        }
      }

      assert {:ok, %Signal{} = signal} = DiscordInteraction.from_discord(raw_payload)
      assert signal.sender == "44444444"
      assert signal.topic == "discord:interaction:11111111"
      assert signal.payload.type == 2
      assert signal.payload.token == "abc_interaction_token"
      assert signal.payload.application_id == "998877"
      assert signal.payload.locale == "en-US"
      assert signal.payload.data.name == "verify_bounty"
    end

    test "from_discord/1 fails on missing token" do
      raw_payload = %{
        "id" => "11111111",
        "type" => 2
      }

      assert {:error, _errors} = DiscordInteraction.from_discord(raw_payload)
    end

    test "from_discord/1 defensively handles malformed inputs" do
      # Non-map input
      assert {:error, [%{"message" => "Expected payload to be a map"}]} = DiscordInteraction.from_discord("invalid")
    end

    test "from_discord/1 fails when required id is nil" do
      raw_payload = %{
        "id" => nil,
        "type" => 2,
        "token" => "abc"
      }
      assert {:error, _errors} = DiscordInteraction.from_discord(raw_payload)
    end

    test "from_discord/1 handles list of non-map options gracefully" do
      raw_payload = %{
        "id" => "11111111",
        "type" => 2,
        "token" => "abc",
        "data" => %{
          "name" => "test",
          "options" => ["not_a_map", %{"name" => "x", "type" => 3, "value" => "val"}]
        }
      }
      assert {:ok, %Signal{} = signal} = DiscordInteraction.from_discord(raw_payload)
      assert [%{name: "x", type: 3, value: "val"}] = signal.payload.data.options
    end

    test "to_discord/1 converts validated interaction back successfully" do
      raw_payload = %{
        "id" => "111",
        "type" => 3, # MESSAGE_COMPONENT
        "token" => "component_token",
        "application_id" => "123456",
        "locale" => "fr"
      }

      {:ok, signal} = DiscordInteraction.from_discord(raw_payload)
      serialized = DiscordInteraction.to_discord(signal)

      assert serialized["id"] == "111"
      assert serialized["type"] == 3
      assert serialized["token"] == "component_token"
      assert serialized["application_id"] == "123456"
      assert serialized["locale"] == "fr"
    end
  end

  describe "DiscordPresenceSignal" do
    test "from_discord/1 converts valid presence successfully" do
      raw_payload = %{
        "user_id" => "999999",
        "status" => "online",
        "guild_id" => "888888",
        "activities" => [
          %{
            "name" => "Visual Studio Code",
            "type" => 0, # PLAYING
            "state" => "Coding Lux integration"
          }
        ]
      }

      assert {:ok, %Signal{} = signal} = DiscordPresence.from_discord(raw_payload)
      assert signal.sender == "999999"
      assert signal.topic == "discord:presence:999999"
      assert signal.payload.status == "online"
      assert [act] = signal.payload.activities
      assert act.name == "Visual Studio Code"
    end

    test "from_discord/1 parses user ID from nested Gateway user structure" do
      raw_payload = %{
        "user" => %{
          "id" => "777777"
        },
        "status" => "idle"
      }

      assert {:ok, %Signal{} = signal} = DiscordPresence.from_discord(raw_payload)
      assert signal.sender == "777777"
      assert signal.payload.user_id == "777777"
    end

    test "from_discord/1 validates enum status constraints" do
      # Status 'sleeping' is invalid
      raw_payload = %{
        "user_id" => "999999",
        "status" => "sleeping"
      }

      assert {:error, _errors} = DiscordPresence.from_discord(raw_payload)
    end

    test "from_discord/1 fails on missing user_id or status" do
      raw_payload1 = %{"status" => "online"}
      raw_payload2 = %{"user_id" => "123"}
      assert {:error, _} = DiscordPresence.from_discord(raw_payload1)
      assert {:error, _} = DiscordPresence.from_discord(raw_payload2)
    end

    test "from_discord/1 handles list of non-map activities gracefully" do
      raw_payload = %{
        "user_id" => "999999",
        "status" => "online",
        "activities" => ["not_a_map", %{"name" => "Playing", "type" => 0}]
      }
      assert {:ok, %Signal{} = signal} = DiscordPresence.from_discord(raw_payload)
      assert [%{name: "Playing", type: 0}] = signal.payload.activities
    end

    test "to_discord/1 converts validated presence back to Gateway User Object shape" do
      raw_payload = %{
        "user_id" => "55555",
        "status" => "dnd",
        "activities" => [
          %{
            "name" => "Elixir",
            "type" => 1,
            "details" => "Live Coding"
          }
        ]
      }

      {:ok, signal} = DiscordPresence.from_discord(raw_payload)
      serialized = DiscordPresence.to_discord(signal)

      # Must output raw Gateway user object structure
      assert serialized["user"]["id"] == "55555"
      assert serialized["status"] == "dnd"
      assert [act] = serialized["activities"]
      assert act["name"] == "Elixir"
      assert act["details"] == "Live Coding" # Verifies fix of key check bug!
    end
  end

  describe "Signal Processing Pipeline" do
    test "pipeline: flows through Agent signal handler successfully" do
      # 1. Setup local router and agent registry
      unique_id = System.unique_integer([:positive])
      registry_name = :"agent_registry_#{unique_id}"
      hub_name = :"test_hub_#{unique_id}"
      router_name = :"test_router_#{unique_id}"

      # Start required processes
      start_supervised!({Registry, keys: :duplicate, name: registry_name})
      start_supervised!({Lux.AgentHub, name: hub_name})
      start_supervised!({Lux.Signal.Router.Local, name: router_name})

      # 2. Start the test agent under supervision with test_process set in template_opts
      agent_name = :"test_agent_#{unique_id}"
      {:ok, agent_pid} = start_supervised({TestDiscordAgent, %{
        name: agent_name,
        template_opts: %{test_process: self()}
      }})

      agent_state = :sys.get_state(agent_pid)

      # Register the agent with the hub
      :ok = Lux.AgentHub.register(hub_name, agent_state, agent_pid, [:discord])

      # 3. Create the DiscordMessage signal
      raw_payload = %{
        "content" => "Hello pipeline integration!",
        "channel_id" => "1234",
        "author" => %{"id" => "5678", "username" => "piped"}
      }
      {:ok, signal} = DiscordMessage.from_discord(raw_payload)

      # Target the specific registered agent
      signal = %Signal{signal | recipient: agent_state.id}

      # 4. Subscribe to the signal delivery events
      :ok = Lux.Signal.Router.Local.subscribe(signal.id, name: router_name)

      # 5. Route the signal through the local router
      assert :ok = Lux.Signal.Router.Local.route(signal, name: router_name, hub: hub_name)

      # 6. Verify the signal was delivered successfully
      assert_receive {:signal_delivered, signal_id}, 2000
      assert signal_id == signal.id

      # 7. Verify the agent actually received and handled the signal
      assert_receive {:handled_signal, handled_signal}, 2000
      assert handled_signal.payload.content == "Hello pipeline integration!"
    end
  end
end
