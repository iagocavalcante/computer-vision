defmodule ComputerVision.Validator do
  @enforce_keys [:socket]
  defstruct @enforce_keys
end

defimpl Membrane.RTMP.MessageValidator, for: ComputerVision.Validator do
  alias ComputerVision.LiveStream

  @impl true
  def validate_release_stream(_impl, _message) do
    {:ok, "stream released"}
  end

  @impl true
  def validate_publish(impl, message) do
    validate_stream_key(impl, message.stream_key)
  end

  @impl true
  def validate_set_data_frame(_impl, _message) do
    {:ok, "set data frame successful"}
  end

  @spec validate_stream_key(Membrane.RTMP.MessageValidator.t(), String.t()) ::
          {:error, any()} | {:ok, any()}
  defp validate_stream_key(impl, stream_key) do
    [username, stream_key] = String.split(stream_key, "_")

    bin_stream_key = String.to_binary(stream_key)

    user = %{id: username, username: username}

    case Ecto.UUID.dump(stream_key) do
      {:ok, ^bin_stream_key} ->
        LiveStream.update_live_stream(impl.socket, fn _ ->
          %{is_live?: true, user: user}
        end)

        Phoenix.PubSub.broadcast(Viewbox.PubSub, "toasts", {:streamer_went_live, user})

        {:ok, "publish stream successful"}

      _ ->
        {:error, "bad stream key"}
    end
  end
end
