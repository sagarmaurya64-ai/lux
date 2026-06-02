defmodule Lux.Signals.DiscordInteraction do
  @moduledoc """
  Defines the Discord Interaction Signal struct and bidirectional converters.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.DiscordInteractionSchema

  @doc """
  Converts a raw Discord interaction payload map to a validated Lux.Signal.
  """
  def from_discord(payload) when is_map(payload) do
    id = Map.get(payload, "id") || Map.get(payload, :id)
    type = Map.get(payload, "type") || Map.get(payload, :type)
    token = Map.get(payload, "token") || Map.get(payload, :token)

    normalized_payload = %{
      id: id,
      type: type,
      token: token,
      guild_id: Map.get(payload, "guild_id") || Map.get(payload, :guild_id),
      channel_id: Map.get(payload, "channel_id") || Map.get(payload, :channel_id),
      member: Map.get(payload, "member") || Map.get(payload, :member) || %{},
      data: Map.get(payload, "data") || Map.get(payload, :data) || %{}
    }

    # Identify sender based on member user or direct user details
    member = normalized_payload.member
    user = Map.get(member, "user") || Map.get(member, :user) || Map.get(payload, "user") || Map.get(payload, :user) || %{}
    sender_id = Map.get(user, "id") || Map.get(user, :id) || "unknown_user"

    new(%{
      payload: normalized_payload,
      sender: sender_id,
      topic: "discord:interaction:#{id}"
    })
  end

  @doc """
  Converts a validated Lux.Signal back to a raw Discord API interaction payload map.
  """
  def to_discord(%Lux.Signal{payload: payload}) do
    %{
      "id" => Map.get(payload, :id) || Map.get(payload, "id"),
      "type" => Map.get(payload, :type) || Map.get(payload, "type"),
      "token" => Map.get(payload, :token) || Map.get(payload, "token"),
      "guild_id" => Map.get(payload, :guild_id) || Map.get(payload, "guild_id"),
      "channel_id" => Map.get(payload, :channel_id) || Map.get(payload, "channel_id"),
      "member" => Map.get(payload, :member) || Map.get(payload, "member") || %{},
      "data" => Map.get(payload, :data) || Map.get(payload, "data") || %{}
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
