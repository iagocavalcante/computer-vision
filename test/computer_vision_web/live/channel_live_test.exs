defmodule ComputerVisionWeb.ChannelLiveTest do
  use ComputerVisionWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    {:ok, streamer} =
      ComputerVision.Accounts.register_user(%{
        email: "streamer@test.com",
        username: "teststreamer",
        password: "validpassword123"
      })

    {:ok, channel} =
      ComputerVision.Streaming.create_channel(%{user_id: streamer.id, title: "Live Stream"})

    %{streamer: streamer, channel: channel}
  end

  test "renders channel page for existing user", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/c/teststreamer")
    assert html =~ "teststreamer"
    assert html =~ "Offline"
  end

  test "redirects for non-existent user", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/c/nonexistent")
  end

  test "shows LIVE when channel is streaming", %{conn: conn, channel: channel} do
    ComputerVision.Streaming.set_channel_live(channel, true)
    {:ok, _view, html} = live(conn, ~p"/c/teststreamer")
    assert html =~ "LIVE"
  end

  test "shows follow button for authenticated user", %{conn: conn} do
    {:ok, viewer} =
      ComputerVision.Accounts.register_user(%{
        email: "v@test.com",
        username: "viewer",
        password: "validpassword123"
      })

    conn = log_in_user(conn, viewer)
    {:ok, _view, html} = live(conn, ~p"/c/teststreamer")
    assert html =~ "Follow"
  end

  test "shows login link for chat when unauthenticated", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/c/teststreamer")
    assert html =~ "Log in to chat"
  end
end
