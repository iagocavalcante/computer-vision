defmodule ComputerVisionWeb.Admin.AdminLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       site_name: Admin.get("site_name", "ComputerVision"),
       registration_open: Admin.get("registration_open", "true"),
       max_concurrent_transcodes: Admin.get("max_concurrent_transcodes", "3"),
       transcoding_enabled_default: Admin.get("transcoding_enabled_default", "false")
     )}
  end

  @impl true
  def handle_event("save_settings", %{"settings" => params}, socket) do
    Admin.set("site_name", params["site_name"])
    Admin.set("registration_open", params["registration_open"] || "false")
    Admin.set("max_concurrent_transcodes", params["max_concurrent_transcodes"])
    Admin.set("transcoding_enabled_default", params["transcoding_enabled_default"] || "false")

    {:noreply,
     socket
     |> assign(
       site_name: params["site_name"],
       registration_open: params["registration_open"] || "false",
       max_concurrent_transcodes: params["max_concurrent_transcodes"],
       transcoding_enabled_default: params["transcoding_enabled_default"] || "false"
     )
     |> put_flash(:info, "Settings saved")}
  end
end
