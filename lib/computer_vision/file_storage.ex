defmodule ComputerVision.FileStorage do
  @moduledoc """
  `Membrane.HTTPAdaptiveStream.Storage` implementation that saves the stream to
  files locally based on the user's stream key.
  """
  @behaviour Membrane.HTTPAdaptiveStream.Storage

  @enforce_keys [:location, :socket]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          location: Path.t(),
          socket: port()
        }

  alias ComputerVision.LiveStream

  @stream_output_file Application.compile_env(:viewbox, :stream_output_file, "index.m3u8")
  @stream_live_file Application.compile_env(:viewbox, :stream_live_file, "live.m3u8")
  @stream_live_dir Application.compile_env(:viewbox, :stream_live_dir, "live")
  @stream_live_segments_offset Application.compile_env(:viewbox, :stream_live_segments_offset, 4)

  @impl true
  def init(%__MODULE__{} = config), do: config

  @impl true
  def store(
        _parent_id,
        name,
        contents,
        _metadata,
        %{mode: :binary},
        state
      ) do
    {File.write(build_output_folder(state, name), contents, [:binary]), state}
  end

  @impl true
  def store(
        _parent_id,
        @stream_output_file = name,
        contents,
        _metadata,
        %{mode: :text},
        state
      ) do
    {File.write(build_output_folder(state, name), contents), state}
  end

  def store(
        _parent_id,
        name,
        contents,
        _metadata,
        %{mode: :text},
        state
      ) do
    contents
    |> prepare_live_manifest()
    |> then(&File.write(build_output_folder(state, @stream_live_file), &1))

    {File.write(build_output_folder(state, name), contents), state}
  end

  @impl true
  def remove(_parent_id, name, _ctx, state) do
    {File.rm(build_output_folder(state, name)), state}
  end

  defp build_output_folder(state, name) do
    %LiveStream{user: user} =
      LiveStream.update_live_stream(state.socket, fn _ -> %{is_live?: true} end)

    path = [state.location, Integer.to_string(user.id), @stream_live_dir, name] |> Path.join()
    File.mkdir_p!(Path.dirname(path))
    path
  end

  defp prepare_live_manifest(contents) do
    re_segments = ~r/\#EXT-X-PROGRAM-DATE-TIME:.*\n\#EXTINF:.*,\nmuxed_segment.*\n?/
    re_sequence = ~r/\#EXT-X-MEDIA-SEQUENCE:\d+/

    segments = Regex.scan(re_segments, contents) |> Enum.map(fn [seg] -> seg end)
    segments_len = length(segments)

    case segments_len > @stream_live_segments_offset do
      true ->
        diff = segments_len - @stream_live_segments_offset

        live_segments =
          segments
          |> Enum.slice(diff..-1)
          |> Enum.join()

        contents
        |> String.replace(Enum.join(segments), live_segments)
        |> String.replace(re_sequence, "#EXT-X-MEDIA-SEQUENCE:#{diff}")

      false ->
        contents
        |> String.replace(re_sequence, "#EXT-X-MEDIA-SEQUENCE:#{segments_len - 1}")
    end
  end
end
