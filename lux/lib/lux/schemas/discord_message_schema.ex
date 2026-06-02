defmodule Lux.Schemas.DiscordMessageSchema do
  @moduledoc """
  Defines the schema for a Discord Message signal.
  """
  use Lux.SignalSchema,
    name: "discord_message",
    version: "1.0.0",
    description: "Represents an incoming or outgoing message from a Discord channel",
    schema: %{
      type: :object,
      properties: %{
        content: %{
          type: :string,
          description: "The raw text content of the Discord message (max 2000 characters)"
        },
        channel_id: %{
          type: :string,
          description: "The Snowflake ID of the channel where the message was sent"
        },
        guild_id: %{
          type: :string,
          description: "The Snowflake ID of the guild/server where the message was sent (optional for DMs)"
        },
        author: %{
          type: :object,
          properties: %{
            id: %{
              type: :string,
              description: "The Snowflake ID of the author"
            },
            username: %{
              type: :string,
              description: "The username of the author"
            },
            bot: %{
              type: :boolean,
              description: "Whether the author is a bot"
            }
          },
          required: ["id", "username"]
        },
        attachments: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{
                type: :string,
                description: "Snowflake ID of the attachment"
              },
              filename: %{
                type: :string,
                description: "The filename of the attachment"
              },
              url: %{
                type: :string,
                description: "Direct download URL of the attachment"
              }
            },
            required: ["id", "filename", "url"]
          }
        },
        embeds: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string},
              description: %{type: :string},
              url: %{type: :string}
            }
          }
        },
        components: %{
          type: :array,
          items: %{type: :object}
        },
        timestamp: %{
          type: :string,
          description: "ISO-8601 formatted string of when the message was sent"
        },
        id: %{
          type: :string,
          description: "The Snowflake ID of the message"
        },
        type: %{
          type: :integer,
          description: "The type of the message"
        },
        mentions: %{
          type: :array,
          items: %{type: :object},
          description: "The list of users mentioned in the message"
        },
        referenced_message: %{
          type: :object,
          description: "The message that this message is in reply to (optional)"
        },
        flags: %{
          type: :integer,
          description: "The message flags"
        },
        edited_timestamp: %{
          type: :string,
          description: "ISO-8601 formatted string of when the message was edited (optional)"
        }
      },
      required: ["content", "channel_id", "author"]
    }
end
