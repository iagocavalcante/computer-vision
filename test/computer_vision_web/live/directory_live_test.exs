defmodule ComputerVisionWeb.DirectoryLiveTest do
  use ComputerVisionWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders directory page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "ComputerVision"
    assert html =~ "No one is live right now"
  end

  test "shows live channels", %{conn: conn} do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: "s@test.com",
        username: "streamer1",
        password: "validpassword123"
      })

    {:ok, channel} =
      ComputerVision.Streaming.create_channel(%{user_id: user.id, title: "Test Stream"})

    ComputerVision.Streaming.set_channel_live(channel, true)

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Test Stream"
    assert html =~ "streamer1"
    assert html =~ "LIVE"
  end

  test "category filter works", %{conn: conn} do
    {:ok, cat} =
      ComputerVision.Streaming.create_category(%{name: "Gaming", slug: "gaming"})

    {:ok, view, _html} = live(conn, ~p"/")

    assert render_click(view, "filter_category", %{"category_id" => to_string(cat.id)}) =~
             "Gaming"
  end

  test "search works", %{conn: conn} do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: "s@test.com",
        username: "findme",
        password: "validpassword123"
      })

    {:ok, channel} =
      ComputerVision.Streaming.create_channel(%{user_id: user.id, title: "Searchable"})

    ComputerVision.Streaming.set_channel_live(channel, true)

    {:ok, view, _html} = live(conn, ~p"/")
    html = render_change(view, "search", %{"query" => "findme"})
    assert html =~ "Searchable"
  end
end
