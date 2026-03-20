defmodule ComputerVision.StreamRegistry do
  @moduledoc "Registry for active stream pipelines. Maps channel identifiers to pipeline PIDs."

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def register(channel_id, pid \\ self()) do
    Registry.register(__MODULE__, channel_id, pid)
  end

  def unregister(channel_id) do
    Registry.unregister(__MODULE__, channel_id)
  end

  def lookup(channel_id) do
    case Registry.lookup(__MODULE__, channel_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
