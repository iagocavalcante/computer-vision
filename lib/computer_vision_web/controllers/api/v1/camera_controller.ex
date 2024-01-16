defmodule ComputerVisionWeb.Api.V1.CameraController do
  use ComputerVisionWeb, :controller

  alias ComputerVision.MembraneService

  def index(conn, _params) do
    {:ok, _} = MembraneService.start_link()
    conn |> put_status(:ok) |> text("Hello World")
  end
end
