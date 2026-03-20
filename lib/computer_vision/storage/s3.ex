defmodule ComputerVision.Storage.S3 do
  @behaviour ComputerVision.Storage

  def write_segment(_base_dir, user_id, stream_id, filename, data) do
    bucket = Application.get_env(:computer_vision, :s3_bucket)
    key = "streams/#{user_id}/#{stream_id}/#{filename}"

    case ExAws.S3.put_object(bucket, key, data) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def read_segment(_base_dir, user_id, stream_id, filename) do
    bucket = Application.get_env(:computer_vision, :s3_bucket)
    key = "streams/#{user_id}/#{stream_id}/#{filename}"

    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_stream(_base_dir, user_id, stream_id) do
    bucket = Application.get_env(:computer_vision, :s3_bucket)
    prefix = "streams/#{user_id}/#{stream_id}/"

    ExAws.S3.list_objects(bucket, prefix: prefix)
    |> ExAws.stream!()
    |> Enum.each(fn %{key: key} -> ExAws.S3.delete_object(bucket, key) |> ExAws.request() end)

    :ok
  end
end
