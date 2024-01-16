defmodule ComputerVisionWeb.CameraChannel do
  use ComputerVisionWeb, :channel

  alias ComputerVision.MembraneService

  def join("camera:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("camera:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    case MembraneService.start_link() do
      {:ok, _} ->
        IO.inspect("RTSP session started")
        broadcast!(socket, "new_msg", %{body: body})
        {:noreply, socket}

      {:error, _} ->
        IO.inspect("RTSP session error")
        {:noreply, socket}
    end
  end
end
