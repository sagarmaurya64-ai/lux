defmodule Lux.Schemas.DiscordPresenceSchema do
  @moduledoc """
  Defines the schema for a Discord Presence signal (status updates, status messages, activities).
  """
  use Lux.SignalSchema,
    name: "discord_presence",
    version: "1.0.0",
    description: "Represents a Discord member presence update (Status, custom activities, client status)",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The Snowflake ID of the user"
        },
        status: %{
          type: :string,
          enum: ["online", "idle", "dnd", "offline"],
          description: "The online status state of the user"
        },
        guild_id: %{
          type: :string,
          description: "The Snowflake ID of the guild/server where the presence update occurred"
        },
        activities: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              type: %{type: :integer},
              state: %{type: :string},
              details: %{type: :string}
            },
            required: ["name", "type"]
          }
        }
      },
      required: ["user_id", "status"]
    }
end
