defmodule ComputerVisionWeb.Admin.AdminLiveTest do
  use ComputerVisionWeb.ConnCase

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, admin} =
      ComputerVision.Accounts.register_user(%{
        email: "admin@test.com",
        username: "admin",
        password: "validpassword123",
        role: "admin"
      })

    conn = log_in_user(conn, admin)
    %{conn: conn, admin: admin}
  end

  test "renders admin page for admin user", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin")
    assert html =~ "Instance Settings"
  end

  test "non-admin user is redirected" do
    {:ok, regular} =
      ComputerVision.Accounts.register_user(%{
        email: "regular@test.com",
        username: "regular",
        password: "validpassword123"
      })

    conn = build_conn() |> log_in_user(regular)
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
  end

  test "unauthenticated user is redirected" do
    conn = build_conn()
    assert {:error, {:redirect, _}} = live(conn, ~p"/admin")
  end

  test "categories page loads", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/categories")
    assert html =~ "Category Management"
    assert html =~ "Add Category"
  end
end
