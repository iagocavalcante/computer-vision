defmodule ComputerVision.SocialTest do
  use ComputerVision.DataCase

  alias ComputerVision.Social

  setup do
    {:ok, follower} =
      ComputerVision.Accounts.register_user(%{
        email: "follower@example.com",
        username: "follower",
        password: "validpassword123"
      })

    {:ok, streamer} =
      ComputerVision.Accounts.register_user(%{
        email: "streamer@example.com",
        username: "streamer",
        password: "validpassword123"
      })

    %{follower: follower, streamer: streamer}
  end

  test "follow_user/2 creates a follow", %{follower: follower, streamer: streamer} do
    assert {:ok, follow} = Social.follow_user(follower.id, streamer.id)
    assert follow.follower_id == follower.id
    assert follow.streamer_id == streamer.id
  end

  test "follow_user/2 prevents self-follow", %{follower: follower} do
    assert {:error, _} = Social.follow_user(follower.id, follower.id)
  end

  test "unfollow_user/2 removes a follow", %{follower: follower, streamer: streamer} do
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    assert :ok = Social.unfollow_user(follower.id, streamer.id)
    assert Social.following?(follower.id, streamer.id) == false
  end

  test "list_follower_ids/1 returns follower ids", %{follower: follower, streamer: streamer} do
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    followers = Social.list_follower_ids(streamer.id)
    assert follower.id in followers
  end

  test "follower_count/1 returns count", %{follower: follower, streamer: streamer} do
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    assert Social.follower_count(streamer.id) == 1
  end

  test "create_notification/1 and list_unread/1", %{follower: follower} do
    {:ok, notif} =
      Social.create_notification(%{
        user_id: follower.id,
        type: "streamer_went_live",
        payload: %{"username" => "streamer"}
      })

    unread = Social.list_unread_notifications(follower.id)
    assert length(unread) == 1
    assert hd(unread).id == notif.id
  end

  test "mark_notifications_read/1 marks all as read", %{follower: follower} do
    {:ok, _} = Social.create_notification(%{user_id: follower.id, type: "test", payload: %{}})
    Social.mark_notifications_read(follower.id)
    assert Social.list_unread_notifications(follower.id) == []
  end

  test "follower_count returns 0 for no followers", %{streamer: streamer} do
    assert Social.follower_count(streamer.id) == 0
  end

  test "following? returns false when not following", %{follower: follower, streamer: streamer} do
    assert Social.following?(follower.id, streamer.id) == false
  end

  test "duplicate follow returns error", %{follower: follower, streamer: streamer} do
    {:ok, _} = Social.follow_user(follower.id, streamer.id)
    assert {:error, _} = Social.follow_user(follower.id, streamer.id)
  end
end
