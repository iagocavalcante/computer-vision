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

  describe "query correctness" do
    test "list_live_channels returns ordered by viewer_count desc" do
      user1 = insert_user("u1@test.com", "user1")
      user2 = insert_user("u2@test.com", "user2")
      {:ok, c1} = Streaming.create_channel(%{user_id: user1.id, viewer_count: 10})
      {:ok, c2} = Streaming.create_channel(%{user_id: user2.id, viewer_count: 50})
      {:ok, _} = Streaming.set_channel_live(c1, true)
      {:ok, _} = Streaming.set_channel_live(c2, true)
      [first | _] = Streaming.list_live_channels()
      assert first.viewer_count == 50
    end

    test "list_live_channels excludes offline channels" do
      user = insert_user("offline@test.com", "offlineuser")
      {:ok, _} = Streaming.create_channel(%{user_id: user.id, is_live: false})
      assert Streaming.list_live_channels() == []
    end

    test "search_live_channels is case-insensitive" do
      user = insert_user("u@test.com", "StreamerBob")
      {:ok, c} = Streaming.create_channel(%{user_id: user.id, title: "My Cool Stream"})
      {:ok, _} = Streaming.set_channel_live(c, true)
      assert length(Streaming.search_live_channels("streamerbob")) == 1
      assert length(Streaming.search_live_channels("cool stream")) == 1
    end

    test "search_live_channels returns empty for no matches" do
      assert Streaming.search_live_channels("nonexistent") == []
    end

    test "list_live_channels_by_category filters correctly" do
      user = insert_user("cat@test.com", "catuser")
      {:ok, cat} = Streaming.create_category(%{name: "Gaming", slug: "gaming"})
      {:ok, c} = Streaming.create_channel(%{user_id: user.id, category_id: cat.id})
      {:ok, _} = Streaming.set_channel_live(c, true)
      assert length(Streaming.list_live_channels_by_category(cat.id)) == 1
      assert length(Streaming.list_live_channels_by_category(999)) == 0
    end
  end

  describe "update_channel/2" do
    test "updates channel title" do
      user = insert_user("upd@test.com", "upduser")
      {:ok, channel} = Streaming.create_channel(%{user_id: user.id, title: "Old"})
      {:ok, updated} = Streaming.update_channel(channel, %{title: "New Title"})
      assert updated.title == "New Title"
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
