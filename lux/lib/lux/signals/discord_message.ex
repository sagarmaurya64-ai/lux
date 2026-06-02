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
    id = Map.get(payload, "id") || Map.get(payload, :id)

    normalized_payload = %{
      id: id,
      content: Map.get(payload, "content") || Map.get(payload, :content),
      channel_id: channel_id,
      guild_id: Map.get(payload, "guild_id") || Map.get(payload, :guild_id),
      author: author,
      attachments: parse_attachments(Map.get(payload, "attachments") || Map.get(payload, :attachments)),
      embeds: Map.get(payload, "embeds") || Map.get(payload, :embeds) || [],
      components: Map.get(payload, "components") || Map.get(payload, :components) || [],
      timestamp: Map.get(payload, "timestamp") || Map.get(payload, :timestamp),
      type: Map.get(payload, "type") || Map.get(payload, :type),
      mentions: parse_mentions(Map.get(payload, "mentions") || Map.get(payload, :mentions)),
      referenced_message: parse_referenced_message(Map.get(payload, "referenced_message") || Map.get(payload, :referenced_message)),
      flags: Map.get(payload, "flags") || Map.get(payload, :flags),
      edited_timestamp: Map.get(payload, "edited_timestamp") || Map.get(payload, :edited_timestamp)
    }

    # Extract sender ID safely and cleanly
    sender_id =
      cond do
        author && (author[:id] || author["id"]) -> author[:id] || author["id"]
        true -> "unknown_author"
      end

    new(%{
      payload: normalized_payload,
      sender: sender_id,
      topic: "discord:message:#{channel_id}"
    })
  end

  # Fallback to handle malformed inputs gracefully instead of raising function clause error
  def from_discord(_) do
    {:error, [%{"message" => "Expected payload to be a map", "path" => []}]}
  end

  @doc """
  Converts a validated Lux.Signal back to a raw Discord API payload map.
  """
  def to_discord(%Lux.Signal{payload: payload}) do
    %{
      "id" => Map.get(payload, :id) || Map.get(payload, "id"),
      "content" => Map.get(payload, :content) || Map.get(payload, "content"),
      "channel_id" => Map.get(payload, :channel_id) || Map.get(payload, "channel_id"),
      "guild_id" => Map.get(payload, :guild_id) || Map.get(payload, "guild_id"),
      "author" => serialize_author(Map.get(payload, :author) || Map.get(payload, "author")),
      "attachments" => serialize_attachments(Map.get(payload, :attachments) || Map.get(payload, "attachments")),
      "embeds" => Map.get(payload, :embeds) || Map.get(payload, "embeds") || [],
      "components" => Map.get(payload, :components) || Map.get(payload, "components") || [],
      "timestamp" => Map.get(payload, :timestamp) || Map.get(payload, "timestamp"),
      "type" => Map.get(payload, :type) || Map.get(payload, "type"),
      "mentions" => serialize_mentions(Map.get(payload, :mentions) || Map.get(payload, "mentions")),
      "referenced_message" => serialize_referenced_message(Map.get(payload, :referenced_message) || Map.get(payload, "referenced_message")),
      "flags" => Map.get(payload, :flags) || Map.get(payload, "flags"),
      "edited_timestamp" => Map.get(payload, :edited_timestamp) || Map.get(payload, "edited_timestamp")
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
  defp parse_author(_), do: nil

  defp parse_attachments(attachments) when is_list(attachments) do
    Enum.reduce(attachments, [], fn
      att, acc when is_map(att) ->
        id = Map.get(att, "id") || Map.get(att, :id)
        filename = Map.get(att, "filename") || Map.get(att, :filename)
        url = Map.get(att, "url") || Map.get(att, :url)

        if id && filename && url do
          acc ++ [%{id: id, filename: filename, url: url}]
        else
          acc
        end
      _, acc ->
        acc
    end)
  end
  defp parse_attachments(_), do: []

  defp parse_mentions(mentions) when is_list(mentions) do
    Enum.reduce(mentions, [], fn
      m, acc when is_map(m) ->
        id = Map.get(m, "id") || Map.get(m, :id)
        username = Map.get(m, "username") || Map.get(m, :username)

        if id && username do
          acc ++ [%{
            id: id,
            username: username,
            bot: Map.get(m, "bot") || Map.get(m, :bot) || false
          }]
        else
          acc
        end
      _, acc ->
        acc
    end)
  end
  defp parse_mentions(_), do: []

  defp parse_referenced_message(nil), do: nil
  defp parse_referenced_message(msg) when is_map(msg) do
    %{
      id: Map.get(msg, "id") || Map.get(msg, :id),
      content: Map.get(msg, "content") || Map.get(msg, :content),
      channel_id: Map.get(msg, "channel_id") || Map.get(msg, :channel_id),
      author: parse_author(Map.get(msg, "author") || Map.get(msg, :author))
    }
  end
  defp parse_referenced_message(_), do: nil

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
        "filename" => Map.get(att, :filename) || Map.get(att, :filename),
        "url" => Map.get(att, :url) || Map.get(att, "url")
      }
    end)
  end
  defp serialize_attachments(_), do: []

  defp serialize_mentions(nil), do: []
  defp serialize_mentions(mentions) when is_list(mentions) do
    Enum.map(mentions, fn m ->
      %{
        "id" => Map.get(m, :id) || Map.get(m, "id"),
        "username" => Map.get(m, :username) || Map.get(m, "username"),
        "bot" => Map.get(m, :bot) || Map.get(m, "bot") || false
      }
    end)
  end
  defp serialize_mentions(_), do: []

  defp serialize_referenced_message(nil), do: nil
  defp serialize_referenced_message(msg) when is_map(msg) do
    %{
      "id" => Map.get(msg, :id) || Map.get(msg, "id"),
      "content" => Map.get(msg, :content) || Map.get(msg, "content"),
      "channel_id" => Map.get(msg, :channel_id) || Map.get(msg, "channel_id"),
      "author" => serialize_author(Map.get(msg, :author) || Map.get(msg, "author"))
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
