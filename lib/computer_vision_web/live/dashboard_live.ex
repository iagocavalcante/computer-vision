defmodule ComputerVisionWeb.DashboardLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.{Streaming, Social, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    channel = Streaming.get_channel_by_user(user.id) || create_default_channel(user)
    categories = Streaming.list_categories()
    follower_count = Social.follower_count(user.id)

    {:ok,
     assign(socket,
       channel: channel,
       categories: categories,
       follower_count: follower_count,
       show_stream_key: false,
       channel_form: to_form(Streaming.Channel.changeset(channel, %{}), as: "channel")
     )}
  end

  @impl true
  def handle_event("toggle_stream_key", _, socket) do
    {:noreply, assign(socket, show_stream_key: !socket.assigns.show_stream_key)}
  end

  @impl true
  def handle_event("regenerate_stream_key", _, socket) do
    user = socket.assigns.current_user
    {:ok, updated_user} = Accounts.regenerate_stream_key(user)
    {:noreply, assign(socket, current_user: updated_user)}
  end

  @impl true
  def handle_event("update_channel", %{"channel" => params}, socket) do
    case Streaming.update_channel(socket.assigns.channel, params) do
      {:ok, channel} ->
        {:noreply, socket |> assign(channel: channel) |> put_flash(:info, "Channel updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, channel_form: to_form(changeset, as: "channel"))}
    end
  end

  defp create_default_channel(user) do
    {:ok, channel} = Streaming.create_channel(%{user_id: user.id})
    channel
  end
end
