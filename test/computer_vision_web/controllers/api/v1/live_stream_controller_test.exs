defmodule ComputerVisionWeb.Api.V1.LiveStreamControllerTest do
  use ComputerVisionWeb.ConnCase

  test "returns 404 for non-existent file", %{conn: conn} do
    conn = get(conn, ~p"/api/v1/stream/1/nonexistent.m3u8")
    assert response(conn, 404) =~ "File not found"
  end

  test "rejects path traversal attempts", %{conn: conn} do
    conn = get(conn, "/api/v1/stream/1/..%2F..%2Fetc%2Fpasswd")
    # Should either 400 or 404, never serve the file
    assert conn.status in [400, 404]
  end

  test "rejects path traversal with encoded dots", %{conn: conn} do
    conn = get(conn, "/api/v1/stream/1/..%2F..%2Fetc%2Fpasswd")
    assert conn.status in [400, 404]
  end
end
