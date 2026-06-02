defmodule Lux.Schemas.DiscordInteractionSchema do
  @moduledoc """
  Defines the schema for a Discord Interaction signal (Slash Commands, components click, modals).
  """
  use Lux.SignalSchema,
    name: "discord_interaction",
    version: "1.0.0",
    description: "Represents a Discord interaction event (Slash Command, Button Click, Modal Submit)",
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "Snowflake ID of the interaction"
        },
        type: %{
          type: :integer,
          description: "Interaction type (1: PING, 2: APPLICATION_COMMAND, 3: MESSAGE_COMPONENT, 4: APPLICATION_COMMAND_AUTOCOMPLETE, 5: MODAL_SUBMIT)"
        },
        token: %{
          type: :string,
          description: "A continuation token for responding to the interaction"
        },
        guild_id: %{
          type: :string,
          description: "The Snowflake ID of the guild/server where the interaction was triggered"
        },
        channel_id: %{
          type: :string,
          description: "The Snowflake ID of the channel where the interaction was triggered"
        },
        member: %{
          type: :object,
          description: "Details of the guild member who triggered the interaction"
        },
        data: %{
          type: :object,
          description: "The payload data specific to the interaction type (e.g. command name, options, custom_id)"
        },
        application_id: %{
          type: :string,
          description: "The application ID of the interaction"
        },
        version: %{
          type: :integer,
          description: "The version of the interaction API"
        },
        locale: %{
          type: :string,
          description: "The locale of the user"
        },
        guild_locale: %{
          type: :string,
          description: "The locale of the guild"
        },
        user: %{
          type: :object,
          description: "The user object who triggered the interaction (for DMs)"
        },
        message: %{
          type: :object,
          description: "The message object associated with component/modal interaction"
        }
      },
      required: ["id", "type", "token"]
    }
end
