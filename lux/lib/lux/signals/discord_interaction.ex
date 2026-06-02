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

    user_payload = Map.get(payload, "user") || Map.get(payload, :user)
    parsed_user = parse_user(user_payload)

    member_payload = Map.get(payload, "member") || Map.get(payload, :member)
    parsed_member = parse_member(member_payload)

    normalized_payload = %{
      id: id,
      type: type,
      token: token,
      guild_id: Map.get(payload, "guild_id") || Map.get(payload, :guild_id),
      channel_id: Map.get(payload, "channel_id") || Map.get(payload, :channel_id),
      application_id: Map.get(payload, "application_id") || Map.get(payload, :application_id),
      version: Map.get(payload, "version") || Map.get(payload, :version),
      locale: Map.get(payload, "locale") || Map.get(payload, :locale),
      guild_locale: Map.get(payload, "guild_locale") || Map.get(payload, :guild_locale),
      member: parsed_member,
      user: parsed_user,
      message: parse_message(Map.get(payload, "message") || Map.get(payload, :message)),
      data: parse_data(Map.get(payload, "data") || Map.get(payload, :data))
    }

    # Identify sender based on member user or direct user details safely
    sender_id =
      cond do
        parsed_member && parsed_member[:user] && (parsed_member[:user][:id] || parsed_member[:user]["id"]) ->
          parsed_member[:user][:id] || parsed_member[:user]["id"]
        parsed_user && (parsed_user[:id] || parsed_user["id"]) ->
          parsed_user[:id] || parsed_user["id"]
        true ->
          "unknown_user"
      end

    new(%{
      payload: normalized_payload,
      sender: sender_id,
      topic: "discord:interaction:#{id}"
    })
  end

  def from_discord(_) do
    {:error, [%{"message" => "Expected payload to be a map", "path" => []}]}
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
      "application_id" => Map.get(payload, :application_id) || Map.get(payload, "application_id"),
      "version" => Map.get(payload, :version) || Map.get(payload, "version"),
      "locale" => Map.get(payload, :locale) || Map.get(payload, "locale"),
      "guild_locale" => Map.get(payload, :guild_locale) || Map.get(payload, "guild_locale"),
      "member" => serialize_member(Map.get(payload, :member) || Map.get(payload, "member")),
      "user" => serialize_user(Map.get(payload, :user) || Map.get(payload, "user")),
      "message" => serialize_message(Map.get(payload, :message) || Map.get(payload, "message")),
      "data" => serialize_data(Map.get(payload, :data) || Map.get(payload, "data"))
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  # --- Helper Parsers ---

  defp parse_user(nil), do: nil
  defp parse_user(user) when is_map(user) do
    %{
      id: Map.get(user, "id") || Map.get(user, :id),
      username: Map.get(user, "username") || Map.get(user, :username),
      discriminator: Map.get(user, "discriminator") || Map.get(user, :discriminator),
      avatar: Map.get(user, "avatar") || Map.get(user, :avatar),
      bot: Map.get(user, "bot") || Map.get(user, :bot) || false
    }
  end
  defp parse_user(_), do: nil

  defp parse_member(nil), do: nil
  defp parse_member(member) when is_map(member) do
    %{
      user: parse_user(Map.get(member, "user") || Map.get(member, :user)),
      nick: Map.get(member, "nick") || Map.get(member, :nick),
      roles: Map.get(member, "roles") || Map.get(member, :roles) || [],
      permissions: Map.get(member, "permissions") || Map.get(member, :permissions)
    }
  end
  defp parse_member(_), do: nil

  defp parse_message(nil), do: nil
  defp parse_message(msg) when is_map(msg) do
    %{
      id: Map.get(msg, "id") || Map.get(msg, :id),
      content: Map.get(msg, "content") || Map.get(msg, :content),
      channel_id: Map.get(msg, "channel_id") || Map.get(msg, :channel_id),
      author: parse_user(Map.get(msg, "author") || Map.get(msg, :author))
    }
  end
  defp parse_message(_), do: nil

  defp parse_data(data) when is_map(data) do
    %{
      id: Map.get(data, "id") || Map.get(data, :id),
      name: Map.get(data, "name") || Map.get(data, :name),
      type: Map.get(data, "type") || Map.get(data, :type),
      custom_id: Map.get(data, "custom_id") || Map.get(data, :custom_id),
      component_type: Map.get(data, "component_type") || Map.get(data, :component_type),
      values: Map.get(data, "values") || Map.get(data, :values) || [],
      options: parse_options(Map.get(data, "options") || Map.get(data, :options)),
      components: Map.get(data, "components") || Map.get(data, :components) || []
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
  defp parse_data(_), do: %{}

  defp parse_options(options) when is_list(options) do
    Enum.reduce(options, [], fn
      opt, acc when is_map(opt) ->
        acc ++ [%{
          name: Map.get(opt, "name") || Map.get(opt, :name),
          type: Map.get(opt, "type") || Map.get(opt, :type),
          value: Map.get(opt, "value") || Map.get(opt, :value)
        }]
      _, acc ->
        acc
    end)
  end
  defp parse_options(_), do: []

  # --- Helper Serializers ---

  defp serialize_user(nil), do: nil
  defp serialize_user(user) when is_map(user) do
    %{
      "id" => Map.get(user, :id) || Map.get(user, "id"),
      "username" => Map.get(user, :username) || Map.get(user, "username"),
      "discriminator" => Map.get(user, :discriminator) || Map.get(user, "discriminator"),
      "avatar" => Map.get(user, :avatar) || Map.get(user, "avatar"),
      "bot" => Map.get(user, :bot) || Map.get(user, "bot") || false
    }
  end

  defp serialize_member(nil), do: nil
  defp serialize_member(member) when is_map(member) do
    %{
      "user" => serialize_user(Map.get(member, :user) || Map.get(member, "user")),
      "nick" => Map.get(member, :nick) || Map.get(member, :nick),
      "roles" => Map.get(member, :roles) || Map.get(member, "roles") || [],
      "permissions" => Map.get(member, :permissions) || Map.get(member, "permissions")
    }
  end

  defp serialize_message(nil), do: nil
  defp serialize_message(msg) when is_map(msg) do
    %{
      "id" => Map.get(msg, :id) || Map.get(msg, "id"),
      "content" => Map.get(msg, :content) || Map.get(msg, "content"),
      "channel_id" => Map.get(msg, :channel_id) || Map.get(msg, "channel_id"),
      "author" => serialize_user(Map.get(msg, :author) || Map.get(msg, "author"))
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp serialize_data(nil), do: nil
  defp serialize_data(data) when is_map(data) do
    %{
      "id" => Map.get(data, :id) || Map.get(data, "id"),
      "name" => Map.get(data, :name) || Map.get(data, "name"),
      "type" => Map.get(data, :type) || Map.get(data, "type"),
      "custom_id" => Map.get(data, :custom_id) || Map.get(data, "custom_id"),
      "component_type" => Map.get(data, :component_type) || Map.get(data, "component_type"),
      "values" => Map.get(data, :values) || Map.get(data, "values") || [],
      "options" => serialize_options(Map.get(data, :options) || Map.get(data, "options")),
      "components" => Map.get(data, :components) || Map.get(data, "components") || []
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp serialize_options(options) when is_list(options) do
    Enum.map(options, fn opt ->
      %{
        "name" => Map.get(opt, :name) || Map.get(opt, "name"),
        "type" => Map.get(opt, :type) || Map.get(opt, "type"),
        "value" => Map.get(opt, :value) || Map.get(opt, "value")
      }
    end)
  end
  defp serialize_options(_), do: []
end
