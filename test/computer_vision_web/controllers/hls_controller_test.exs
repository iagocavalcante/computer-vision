defmodule ComputerVisionWeb.HlsControllerTest do
  use ComputerVisionWeb.ConnCase

  test "returns 404 for non-existent file", %{conn: conn} do
    conn = get(conn, ~p"/video/nonexistent.m3u8")
    assert response(conn, 404) =~ "File not found"
  end

  test "rejects path traversal", %{conn: conn} do
    conn = get(conn, "/video/..%2F..%2Fetc%2Fpasswd")
    assert conn.status in [400, 404]
  end
end
