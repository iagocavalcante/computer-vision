defmodule ComputerVisionWeb.DirectoryLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.Streaming

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ComputerVision.PubSub, "streams")
    end

    channels = Streaming.list_live_channels()
    categories = Streaming.list_categories()

    {:ok,
     assign(socket,
       channels: channels,
       categories: categories,
       selected_category: nil,
       search_query: ""
     )}
  end

  @impl true
  def handle_info({:streamer_went_live, _user, _channel}, socket) do
    channels = Streaming.list_live_channels()
    {:noreply, assign(socket, channels: channels)}
  end

  @impl true
  def handle_info({:stream_ended, _channel_id}, socket) do
    channels = Streaming.list_live_channels()
    {:noreply, assign(socket, channels: channels)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => ""}, socket) do
    channels = Streaming.list_live_channels()
    {:noreply, assign(socket, channels: channels, selected_category: nil)}
  end

  @impl true
  def handle_event("filter_category", %{"category_id" => id}, socket) do
    category_id = String.to_integer(id)
    channels = Streaming.list_live_channels_by_category(category_id)
    {:noreply, assign(socket, channels: channels, selected_category: category_id)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    channels =
      if query == "",
        do: Streaming.list_live_channels(),
        else: Streaming.search_live_channels(query)

    {:noreply, assign(socket, channels: channels, search_query: query)}
  end
end
