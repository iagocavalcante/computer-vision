defmodule ComputerVision.Storage do
  @callback write_segment(String.t(), String.t(), String.t(), String.t(), binary()) ::
              :ok | {:error, term()}
  @callback read_segment(String.t(), String.t(), String.t(), String.t()) ::
              {:ok, binary()} | {:error, term()}
  @callback delete_stream(String.t(), String.t(), String.t()) :: :ok | {:error, term()}

  def impl,
    do: Application.get_env(:computer_vision, :storage_backend, ComputerVision.Storage.Local)

  def base_dir, do: Application.get_env(:computer_vision, :storage_dir, "output")
end
