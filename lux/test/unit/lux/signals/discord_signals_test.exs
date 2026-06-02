defmodule Lux.Signals.DiscordSignalsTest do
  # Use the same UnitAPICase as existing unit tests
  use UnitAPICase, async: true

  alias Lux.Signals.DiscordMessage
  alias Lux.Signals.DiscordInteraction
  alias Lux.Signals.DiscordPresence
  alias Lux.Signal

  describe "DiscordMessageSignal" do
    test "from_discord/1 converts a valid raw message successfully" do
      raw_payload = %{
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
        "timestamp" => "2026-06-02T16:00:00Z"
      }

      assert {:ok, %Signal{} = signal} = DiscordMessage.from_discord(raw_payload)
      assert signal.sender == "112233445566778899"
      assert signal.topic == "discord:message:123456789012345678"
      assert signal.schema_id == Lux.Schemas.DiscordMessageSchema

      payload = signal.payload
      assert payload.content == "Hello standard agent! 🚀"
      assert payload.channel_id == "123456789012345678"
      assert payload.author.username == "test_user"
      assert [att] = payload.attachments
      assert att.filename == "log.txt"
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
      # Missing content
      raw_payload = %{
        "channel_id" => "123456789012345678",
        "author" => %{
          "id" => "112233445566778899",
          "username" => "test_user"
        }
      }

      assert {:error, _errors} = DiscordMessage.from_discord(raw_payload)
    end

    test "to_discord/1 converts a validated signal back to raw Discord format" do
      raw_payload = %{
        "content" => "Converting back!",
        "channel_id" => "12345",
        "author" => %{
          "id" => "6789",
          "username" => "convert_user",
          "bot" => true
        }
      }

      {:ok, signal} = DiscordMessage.from_discord(raw_payload)
      serialized = DiscordMessage.to_discord(signal)

      assert serialized["content"] == "Converting back!"
      assert serialized["channel_id"] == "12345"
      assert serialized["author"]["username"] == "convert_user"
      assert serialized["author"]["bot"] == true
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
        "member" => %{
          "user" => %{
            "id" => "44444444",
            "username" => "commander"
          }
        },
        "data" => %{
          "name" => "verify_bounty",
          "options" => []
        }
      }

      assert {:ok, %Signal{} = signal} = DiscordInteraction.from_discord(raw_payload)
      assert signal.sender == "44444444"
      assert signal.topic == "discord:interaction:11111111"
      assert signal.payload.type == 2
      assert signal.payload.token == "abc_interaction_token"
    end

    test "from_discord/1 fails on missing token" do
      raw_payload = %{
        "id" => "11111111",
        "type" => 2
      }

      assert {:error, _errors} = DiscordInteraction.from_discord(raw_payload)
    end

    test "to_discord/1 converts validated interaction back successfully" do
      raw_payload = %{
        "id" => "111",
        "type" => 3, # MESSAGE_COMPONENT
        "token" => "component_token"
      }

      {:ok, signal} = DiscordInteraction.from_discord(raw_payload)
      serialized = DiscordInteraction.to_discord(signal)

      assert serialized["id"] == "111"
      assert serialized["type"] == 3
      assert serialized["token"] == "component_token"
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
  end
end
