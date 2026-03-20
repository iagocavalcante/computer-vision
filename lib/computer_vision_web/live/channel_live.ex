defmodule ComputerVisionWeb.ChannelLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.{Streaming, Social, Chat, Accounts}
  alias ComputerVisionWeb.Presence

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    user = Accounts.get_user_by_username(username)

    if is_nil(user) do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      channel = Streaming.get_channel_by_user(user.id)

      if connected?(socket) && channel do
        Phoenix.PubSub.subscribe(ComputerVision.PubSub, "chat:#{channel.id}")
        Phoenix.PubSub.subscribe(ComputerVision.PubSub, "channel:#{channel.id}")

        Presence.track(self(), "presence:#{channel.id}", socket.id, %{
          joined_at: System.monotonic_time()
        })

        Phoenix.PubSub.subscribe(ComputerVision.PubSub, "presence:#{channel.id}")
      end

      current_user = socket.assigns[:current_user]
      following = current_user && user && Social.following?(current_user.id, user.id)
      follower_count = Social.follower_count(user.id)

      viewer_count =
        if channel,
          do: Presence.list("presence:#{channel.id}") |> map_size(),
          else: 0

      emotes = if channel, do: Chat.list_emotes(channel.id), else: []

      {:ok,
       assign(socket,
         streamer: user,
         channel: channel,
         is_live: channel != nil && channel.is_live,
         following: following || false,
         follower_count: follower_count,
         viewer_count: viewer_count,
         chat_messages: [],
         chat_form: to_form(%{}, as: "chat"),
         emotes: emotes
       )}
    end
  end

  @impl true
  def handle_info({:chat_message, message}, socket) do
    messages = (socket.assigns.chat_messages ++ [message]) |> Enum.take(-200)
    {:noreply, assign(socket, chat_messages: messages)}
  end

  @impl true
  def handle_info(:stream_ended, socket) do
    {:noreply, assign(socket, is_live: false)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    channel = socket.assigns.channel

    viewer_count =
      if channel,
        do: Presence.list("presence:#{channel.id}") |> map_size(),
        else: 0

    {:noreply, assign(socket, viewer_count: viewer_count)}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("send_message", %{"chat" => %{"message" => content}}, socket) do
    current_user = socket.assigns[:current_user]
    channel = socket.assigns.channel

    cond do
      is_nil(current_user) ->
        {:noreply, put_flash(socket, :error, "You must be logged in to chat")}

      is_nil(channel) ->
        {:noreply, socket}

      Chat.banned?(channel.id, current_user.id) ->
        {:noreply, put_flash(socket, :error, "You are banned from this chat")}

      true ->
        message = %{
          sender: %{id: current_user.id, username: current_user.username},
          content: content,
          timestamp: DateTime.utc_now()
        }

        Phoenix.PubSub.broadcast(
          ComputerVision.PubSub,
          "chat:#{channel.id}",
          {:chat_message, message}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_follow", _, socket) do
    current_user = socket.assigns[:current_user]
    streamer = socket.assigns.streamer

    if is_nil(current_user) do
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    else
      if socket.assigns.following do
        Social.unfollow_user(current_user.id, streamer.id)

        {:noreply,
         assign(socket,
           following: false,
           follower_count: socket.assigns.follower_count - 1
         )}
      else
        {:ok, _} = Social.follow_user(current_user.id, streamer.id)

        {:noreply,
         assign(socket,
           following: true,
           follower_count: socket.assigns.follower_count + 1
         )}
      end
    end
  end
end
