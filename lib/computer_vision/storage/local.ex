defmodule ComputerVision.Storage.Local do
  @behaviour ComputerVision.Storage

  def write_segment(base_dir, user_id, stream_id, filename, data) do
    path = Path.join([base_dir, user_id, stream_id, filename])
    File.mkdir_p!(Path.dirname(path))
    File.write(path, data)
  end

  def read_segment(base_dir, user_id, stream_id, filename) do
    Path.join([base_dir, user_id, stream_id, filename]) |> File.read()
  end

  def delete_stream(base_dir, user_id, stream_id) do
    case File.rm_rf(Path.join([base_dir, user_id, stream_id])) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
