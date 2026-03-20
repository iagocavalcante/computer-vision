defmodule ComputerVision.StreamingTest do
  use ComputerVision.DataCase

  alias ComputerVision.Streaming
  alias ComputerVision.Streaming.Channel

  describe "channels" do
    setup do
      user = insert_user()
      %{user: user}
    end

    test "create_channel/1 creates a channel for a user", %{user: user} do
      assert {:ok, %Channel{} = channel} =
               Streaming.create_channel(%{user_id: user.id, title: "My Stream"})

      assert channel.user_id == user.id
      assert channel.title == "My Stream"
      assert channel.is_live == false
    end

    test "get_channel_by_user/1 returns the channel", %{user: user} do
      {:ok, channel} = Streaming.create_channel(%{user_id: user.id})
      assert Streaming.get_channel_by_user(user.id).id == channel.id
    end

    test "set_channel_live/2 marks channel as live", %{user: user} do
      {:ok, channel} = Streaming.create_channel(%{user_id: user.id})
      {:ok, updated} = Streaming.set_channel_live(channel, true)
      assert updated.is_live == true
      assert updated.started_at != nil
    end

    test "list_live_channels/0 returns only live channels", %{user: user} do
      {:ok, _} = Streaming.create_channel(%{user_id: user.id, is_live: false})
      user2 = insert_user("test2@example.com", "testuser2")
      {:ok, channel2} = Streaming.create_channel(%{user_id: user2.id})
      {:ok, _} = Streaming.set_channel_live(channel2, true)
      live = Streaming.list_live_channels()
      assert length(live) == 1
    end
  end

  describe "categories" do
    test "create_category/1 creates a category" do
      assert {:ok, category} = Streaming.create_category(%{name: "Gaming", slug: "gaming"})
      assert category.name == "Gaming"
      assert category.slug == "gaming"
    end

    test "list_categories/0 returns all categories" do
      {:ok, _} = Streaming.create_category(%{name: "Gaming", slug: "gaming"})
      {:ok, _} = Streaming.create_category(%{name: "Music", slug: "music"})
      assert length(Streaming.list_categories()) == 2
    end

    test "channels can belong to a category" do
      user = insert_user()
      {:ok, category} = Streaming.create_category(%{name: "Gaming", slug: "gaming"})

      {:ok, channel} =
        Streaming.create_channel(%{
          user_id: user.id,
          title: "My Stream",
          category_id: category.id
        })

      assert channel.category_id == category.id
    end
  end

  defp insert_user(email \\ "test@example.com", username \\ "testuser") do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: email,
        username: username,
        password: "validpassword123"
      })

    user
  end
end
