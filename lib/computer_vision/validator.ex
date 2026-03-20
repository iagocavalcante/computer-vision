defmodule ComputerVision.Validator do
  @enforce_keys [:socket]
  defstruct @enforce_keys

  alias ComputerVision.{Accounts, Streaming}

  def validate_stream_key(full_key) do
    case String.split(full_key, "_", parts: 2) do
      [username, stream_key] ->
        case Accounts.get_user_by_username(username) do
          nil ->
            {:error, "user not found"}

          user ->
            if user.stream_key == stream_key do
              ensure_channel(user)
              {:ok, user}
            else
              {:error, "invalid stream key"}
            end
        end

      _ ->
        {:error, "malformed stream key"}
    end
  end

  defp ensure_channel(user) do
    case Streaming.get_channel_by_user(user.id) do
      nil -> Streaming.create_channel(%{user_id: user.id})
      channel -> {:ok, channel}
    end
  end
end

defimpl Membrane.RTMP.MessageValidator, for: ComputerVision.Validator do
  @impl true
  def validate_connect(_impl, _message), do: {:ok, "connect success"}

  @impl true
  def validate_release_stream(_impl, _message), do: {:ok, "stream released"}

  @impl true
  def validate_publish(_impl, message) do
    case ComputerVision.Validator.validate_stream_key(message.stream_key) do
      {:ok, user} ->
        channel = ComputerVision.Streaming.get_channel_by_user(user.id)
        ComputerVision.Streaming.set_channel_live(channel, true)

        Phoenix.PubSub.broadcast(
          ComputerVision.PubSub,
          "streams",
          {:streamer_went_live, user, channel}
        )

        {:ok, "publish stream successful"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def validate_set_data_frame(_impl, _message), do: {:ok, "set data frame successful"}
end
