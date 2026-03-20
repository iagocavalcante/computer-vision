defmodule ComputerVisionWeb.Presence do
  use Phoenix.Presence,
    otp_app: :computer_vision,
    pubsub_server: ComputerVision.PubSub
end
