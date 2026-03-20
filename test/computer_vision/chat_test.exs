defmodule ComputerVision.ChatTest do
  use ComputerVision.DataCase
  alias ComputerVision.Chat

  setup do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: "test@example.com",
        username: "testuser",
        password: "validpassword123"
      })

    {:ok, channel} = ComputerVision.Streaming.create_channel(%{user_id: user.id})
    %{user: user, channel: channel}
  end

  test "create_emote/1 creates a channel emote", %{channel: channel} do
    assert {:ok, emote} =
             Chat.create_emote(%{
               name: "Hype",
               code: ":hype:",
               image_url: "/emotes/hype.png",
               channel_id: channel.id
             })

    assert emote.code == ":hype:"
  end

  test "list_emotes/1 returns channel + global emotes", %{channel: channel} do
    {:ok, _} = Chat.create_emote(%{name: "Global", code: ":global:", image_url: "/g.png"})

    {:ok, _} =
      Chat.create_emote(%{
        name: "Local",
        code: ":local:",
        image_url: "/l.png",
        channel_id: channel.id
      })

    emotes = Chat.list_emotes(channel.id)
    assert length(emotes) == 2
  end

  test "ban_user/1 and banned?/2", %{user: user, channel: channel} do
    {:ok, _} = Chat.ban_user(%{channel_id: channel.id, user_id: user.id, reason: "spam"})
    assert Chat.banned?(channel.id, user.id) == true
  end

  test "unban_user/2 removes ban", %{user: user, channel: channel} do
    {:ok, _} = Chat.ban_user(%{channel_id: channel.id, user_id: user.id})
    :ok = Chat.unban_user(channel.id, user.id)
    assert Chat.banned?(channel.id, user.id) == false
  end

  test "create_emote rejects duplicate code in same channel", %{channel: channel} do
    {:ok, _} =
      Chat.create_emote(%{
        name: "First",
        code: ":dup:",
        image_url: "/a.png",
        channel_id: channel.id
      })

    {:error, changeset} =
      Chat.create_emote(%{
        name: "Second",
        code: ":dup:",
        image_url: "/b.png",
        channel_id: channel.id
      })

    assert errors_on(changeset) != %{}
  end

  test "delete_emote removes the emote", %{channel: channel} do
    {:ok, emote} =
      Chat.create_emote(%{
        name: "Temp",
        code: ":temp:",
        image_url: "/t.png",
        channel_id: channel.id
      })

    {:ok, _} = Chat.delete_emote(emote)
    assert Chat.list_emotes(channel.id) |> Enum.find(&(&1.code == ":temp:")) == nil
  end

  test "expired bans are not active", %{user: user, channel: channel} do
    past = DateTime.add(DateTime.utc_now(), -3600, :second)

    {:ok, _} =
      Chat.ban_user(%{channel_id: channel.id, user_id: user.id, expires_at: past})

    assert Chat.banned?(channel.id, user.id) == false
  end
end
