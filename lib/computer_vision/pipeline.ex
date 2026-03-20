defmodule ComputerVision.Pipeline do
  use Membrane.Pipeline

  alias Membrane.RTMP.SourceBin

  @impl true
  def handle_init(_context, socket: socket) do
    path = Path.join("priv/static/live", "output")

    structure = [
      child(:src, %SourceBin{socket: socket})
      |> via_out(:audio)
      |> via_in(Pad.ref(:input, :audio),
        options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      )
      |> child(:sink, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: :infinity,
        persist?: false,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: path}
      }),
      get_child(:src)
      |> via_out(:video)
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:sink)
    ]

    {[spec: structure], %{socket: socket, since_level: 0}}
  end

  @impl true
  def handle_child_notification(
        {:transcribed, %{results: [%{text: text}]}, part, start, stop},
        :transcription,
        _context,
        state
      ) do
    Phoenix.PubSub.broadcast!(
      ComputerVision.PubSub,
      "transcripts",
      {:transcribed, text, part, start, stop}
    )

    {[], state}
  end

  @impl true
  def handle_child_notification(
        {:transcribed, %{results: [%{text: text}]}, part, start, stop},
        :instant_transcription,
        _context,
        state
      ) do
    Phoenix.PubSub.broadcast!(
      ComputerVision.PubSub,
      "transcripts",
      {:instant, text, part, start, stop}
    )

    {[], state}
  end

  @spacing 20
  @impl true
  def handle_child_notification(
        {:amplitudes, amps},
        _element,
        _context,
        state
      ) do
    now = System.monotonic_time(:millisecond)

    state =
      if now - state.since_level > @spacing do
        Phoenix.PubSub.broadcast!(
          ComputerVision.PubSub,
          "transcripts",
          {:levels, amps}
        )

        %{state | since_level: now}
      else
        state
      end

    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _element, _context, state) do
    {[], state}
  end

  @impl true
  def handle_info({:socket_control_needed, socket, source} = notification, _ctx, state) do
    case SourceBin.pass_control(socket, source) do
      :ok ->
        :ok

      {:error, :not_owner} ->
        Process.send_after(self(), notification, 200)
    end

    {[], state}
  end
end
