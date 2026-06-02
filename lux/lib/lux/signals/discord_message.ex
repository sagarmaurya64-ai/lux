defmodule Lux.Signals.DiscordMessage do
  @moduledoc """
  Defines the Discord Message Signal struct and bidirectional converters.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.DiscordMessageSchema

  @doc """
  Converts a raw Discord API payload map to a validated Lux.Signal.
  """
  def from_discord(payload) when is_map(payload) do
    author = parse_author(Map.get(payload, "author") || Map.get(payload, :author))
    channel_id = Map.get(payload, "channel_id") || Map.get(payload, :channel_id)

    normalized_payload = %{
      content: Map.get(payload, "content") || Map.get(payload, :content) || "",
      channel_id: channel_id,
      guild_id: Map.get(payload, "guild_id") || Map.get(payload, :guild_id),
      author: author,
      attachments: parse_attachments(Map.get(payload, "attachments") || Map.get(payload, :attachments)),
      embeds: Map.get(payload, "embeds") || Map.get(payload, :embeds) || [],
      components: Map.get(payload, "components") || Map.get(payload, :components) || [],
      timestamp: Map.get(payload, "timestamp") || Map.get(payload, :timestamp)
    }

    new(%{
      payload: normalized_payload,
      sender: author[:id] || author["id"],
      topic: "discord:message:#{channel_id}"
    })
  end

  @doc """
  Converts a validated Lux.Signal back to a raw Discord API payload map.
  """
  def to_discord(%Lux.Signal{payload: payload}) do
    %{
      "content" => Map.get(payload, :content) || Map.get(payload, "content"),
      "channel_id" => Map.get(payload, :channel_id) || Map.get(payload, "channel_id"),
      "guild_id" => Map.get(payload, :guild_id) || Map.get(payload, "guild_id"),
      "author" => serialize_author(Map.get(payload, :author) || Map.get(payload, "author")),
      "attachments" => serialize_attachments(Map.get(payload, :attachments) || Map.get(payload, "attachments")),
      "embeds" => Map.get(payload, :embeds) || Map.get(payload, "embeds") || [],
      "components" => Map.get(payload, :components) || Map.get(payload, "components") || [],
      "timestamp" => Map.get(payload, :timestamp) || Map.get(payload, "timestamp")
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  # --- Helper Parsers ---

  defp parse_author(nil), do: nil
  defp parse_author(author) when is_map(author) do
    %{
      id: Map.get(author, "id") || Map.get(author, :id),
      username: Map.get(author, "username") || Map.get(author, :username),
      bot: Map.get(author, "bot") || Map.get(author, :bot) || false
    }
  end

  defp parse_attachments(nil), do: []
  defp parse_attachments(attachments) when is_list(attachments) do
    Enum.map(attachments, fn att ->
      %{
        id: Map.get(att, "id") || Map.get(att, :id),
        filename: Map.get(att, "filename") || Map.get(att, :filename),
        url: Map.get(att, "url") || Map.get(att, :url)
      }
    end)
  end

  # --- Helper Serializers ---

  defp serialize_author(nil), do: nil
  defp serialize_author(author) when is_map(author) do
    %{
      "id" => Map.get(author, :id) || Map.get(author, "id"),
      "username" => Map.get(author, :username) || Map.get(author, "username"),
      "bot" => Map.get(author, :bot) || Map.get(author, "bot") || false
    }
  end

  defp serialize_attachments(nil), do: []
  defp serialize_attachments(attachments) when is_list(attachments) do
    Enum.map(attachments, fn att ->
      %{
        "id" => Map.get(att, :id) || Map.get(att, "id"),
        "filename" => Map.get(att, :filename) || Map.get(att, "filename"),
        "url" => Map.get(att, :url) || Map.get(att, "url")
      }
    end)
  end
end
