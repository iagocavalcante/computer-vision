defmodule ComputerVisionWeb.DashboardLiveTest do
  use ComputerVisionWeb.ConnCase

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, user} =
      ComputerVision.Accounts.register_user(%{
        email: "dash@test.com",
        username: "dashuser",
        password: "validpassword123"
      })

    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  test "renders dashboard for authenticated user", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Streamer Dashboard"
    assert html =~ "Stream Key"
    assert html =~ "Stream Status"
  end

  test "redirects unauthenticated user" do
    conn = build_conn()
    assert {:error, {:redirect, _}} = live(conn, ~p"/dashboard")
  end

  test "toggle stream key visibility", %{conn: conn, user: user} do
    {:ok, view, html} = live(conn, ~p"/dashboard")
    refute html =~ user.stream_key

    html = render_click(view, "toggle_stream_key")
    assert html =~ user.stream_key
  end

  test "update channel title", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dashboard")
    html = render_submit(view, "update_channel", %{"channel" => %{"title" => "New Title"}})
    assert html =~ "Channel updated"
  end
end
