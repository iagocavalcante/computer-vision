defmodule ComputerVisionWeb.LiveStreamLive do
  use ComputerVisionWeb, :live_view

  alias ComputerVision.LiveStream
  alias Plug

  @output_file Application.compile_env(:computer_vision, :stream_live_file, "live.m3u8")

  def mount(params, session, socket) do
    Phoenix.PubSub.subscribe(ComputerVision.PubSub, "live:anom")

    {:ok,
     assign(socket,
       output_file: @output_file,
       live_stream: %LiveStream{},
       user: %{
         id: "anonymous",
         username: "Anonymous"
       },
       chat_messages: [],
       chat_form: to_form(%{}, as: "chat_form"),
       current_chat_input: ""
     )}
  end

  def handle_info(%LiveStream{} = live_stream, socket) do
    {:noreply, assign(socket, live_stream: live_stream)}
  end

  def handle_info({:chat_message, message}, %{assigns: %{chat_messages: chat_messages}} = socket) do
    {:noreply, assign(socket, chat_messages: chat_messages ++ [message])}
  end

  def handle_event(
        "send_message",
        %{"chat_form" => %{"chat_input" => chat_input}},
        socket
      ) do
    Phoenix.PubSub.broadcast(
      ComputerVision.PubSub,
      "live:anom",
      {:chat_message,
       %{
         "sender" => %{username: "Anonymous"},
         "timestamp" => DateTime.utc_now(),
         "content" => chat_input
       }}
    )

    {:noreply, assign(socket, current_chat_input: "")}
  end
end
