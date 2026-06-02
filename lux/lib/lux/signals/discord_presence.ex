defmodule Lux.Signals.DiscordPresence do
  @moduledoc """
  Defines the Discord Presence Signal struct and bidirectional converters.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.DiscordPresenceSchema

  @doc """
  Converts a raw Discord presence payload map to a validated Lux.Signal.
  """
  def from_discord(payload) when is_map(payload) do
    user_id = Map.get(payload, "user_id") || Map.get(payload, :user_id)
    status = Map.get(payload, "status") || Map.get(payload, :status)

    # In raw Gateway events, the user ID is sometimes nested under a "user" block
    user_id =
      if is_nil(user_id) do
        user = Map.get(payload, "user") || Map.get(payload, :user) || %{}
        Map.get(user, "id") || Map.get(user, :id)
      else
        user_id
      end

    normalized_payload = %{
      user_id: user_id,
      status: status,
      guild_id: Map.get(payload, "guild_id") || Map.get(payload, :guild_id),
      activities: parse_activities(Map.get(payload, "activities") || Map.get(payload, :activities))
    }

    new(%{
      payload: normalized_payload,
      sender: user_id,
      topic: "discord:presence:#{user_id}"
    })
  end

  @doc """
  Converts a validated Lux.Signal back to a raw Discord Gateway presence update payload map.
  """
  def to_discord(%Lux.Signal{payload: payload}) do
    %{
      "user_id" => Map.get(payload, :user_id) || Map.get(payload, "user_id"),
      "status" => Map.get(payload, :status) || Map.get(payload, "status"),
      "guild_id" => Map.get(payload, :guild_id) || Map.get(payload, "guild_id"),
      "activities" => serialize_activities(Map.get(payload, :activities) || Map.get(payload, "activities"))
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  # --- Helper Parsers ---

  defp parse_activities(nil), do: []
  defp parse_activities(activities) when is_list(activities) do
    Enum.map(activities, fn act ->
      %{
        name: Map.get(act, "name") || Map.get(act, :name),
        type: Map.get(act, "type") || Map.get(act, :type),
        state: Map.get(act, "state") || Map.get(act, :state),
        details: Map.get(act, "details") || Map.get(act, :details)
      }
    end)
  end

  # --- Helper Serializers ---

  defp serialize_activities(nil), do: []
  defp serialize_activities(activities) when is_list(activities) do
    Enum.map(activities, fn act ->
      %{
        "name" => Map.get(act, :name) || Map.get(act, "name"),
        "type" => Map.get(act, :type) || Map.get(act, "type"),
        "state" => Map.get(act, :state) || Map.get(act, "state"),
        "details" => Map.get(act, :details) || Map.get(act, :details)
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()
    end)
  end
end
