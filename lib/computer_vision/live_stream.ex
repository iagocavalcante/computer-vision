defmodule ComputerVision.LiveStream do
  use Membrane.Pipeline

  alias ComputerVision.LiveStream
  alias Membrane.HTTPAdaptiveStream.Sink
  alias Membrane.RTMP.SourceBin

  @enforce_keys ~w()a
  @optional_keys ~w(user socket)a
  @default_keys [is_live?: true, viewer_count: 0]
  defstruct @enforce_keys ++ @optional_keys ++ @default_keys

  @type t :: %__MODULE__{
          viewer_count: non_neg_integer(),
          socket: port(),
          user: Accounts.User.t(),
          is_live?: boolean()
        }

  @stream_output_dir Application.compile_env(:viewbox, :stream_output_dir, "output")
  @stream_output_file Application.compile_env(:viewbox, :stream_output_file, "index.m3u8")
  @stream_live_dir Application.compile_env(:viewbox, :stream_live_dir, "live")
  @stream_live_file Application.compile_env(:viewbox, :stream_live_file, "live.m3u8")

  @impl true
  def handle_init(_ctx, socket: socket) do
    spec = [
      child(:src, %SourceBin{socket: socket})
      |> via_out(:audio)
      |> via_in(Pad.ref(:input, :audio),
        options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      )
      |> child(:sink, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: :infinity,
        persist?: false,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }),
      get_child(:src)
      |> via_out(:video)
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:sink)
    ]
      # child(:src, %SourceBin{socket: socket}),
      # |> via_out(:audio)
      # |> via_in(Pad.ref(:input, :audio),
      #   options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      # )
      # |> child(:sink, %Membrane.HTTPAdaptiveStream.SinkBin{
      #   manifest_module: Membrane.HTTPAdaptiveStream.HLS,
      #   persist?: true,
      #   target_window_duration: :infinity,
      #   mode: :live,
      #   hls_mode: :muxed_av,
      #   storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      # }),
      # get_child(:src)
      # |> via_out(:video)
      # |> via_in(Pad.ref(:input, :video),
      #   options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      # )
      # |> get_child(:sink)

    {[spec: spec], %{socket: socket}}
  end

  # Once the source initializes, we grant it the control over the tcp socket
  @impl true
  def handle_child_notification(
        {:socket_control_needed, _socket, _source} = notification,
        :src,
        _ctx,
        state
      ) do
    send(self(), notification)

    {[], state}
  end

  def handle_child_notification(notification, _child, _ctx, state)
      when notification in [:end_of_stream, :socket_closed, :unexpected_socket_closed] do
    Membrane.Pipeline.terminate(self())
    {[], state}
  end

  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_info({:socket_control_needed, socket, source} = notification, _ctx, state) do
    case Membrane.RTMP.SourceBin.pass_control(socket, source) do
      :ok ->
        nil

      {:error, :not_owner} ->
        Process.send_after(self(), notification, 200)

      {:error, :closed} ->
        Membrane.Pipeline.terminate(self())
    end

    {[], state}
  end

  # The rest of the module is used for self-termination of the pipeline after processing finishes
  @impl true
  def handle_element_end_of_stream(:sink, _pad, _ctx, state) do
    {[terminate: :shutdown], state}
  end

  @impl true
  def handle_element_end_of_stream(_child, _pad, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_terminate_request(_ctx, state) do
    {[], state}
  end

  def get_thumbnail(user_id, vod_id) do
    dir =
      case vod_id do
        nil -> @stream_live_dir
        vod_id -> Integer.to_string(vod_id)
      end

    [@stream_output_dir, Integer.to_string(user_id), dir]
    |> Path.join()
    |> get_thumbnail_base64()
  end

  defp get_thumbnail_base64(path) do
    from = [path, @stream_output_file] |> Path.join()
    to = [path, "thumbnail.png"] |> Path.join()

    System.cmd(
      "ffmpeg",
      [
        "-i",
        from,
        "-vframes",
        "1",
        "-s",
        "1280x720",
        "-ss",
        "1",
        to,
        "-y",
        "-hide_banner"
      ]
    )

    case File.read(to) do
      {:ok, content} -> Base.encode64(content)
      {:error, _} -> nil
    end
  end
end
