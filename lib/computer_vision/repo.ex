defmodule ComputerVision.Repo do
  use Ecto.Repo,
    otp_app: :computer_vision,
    adapter: Ecto.Adapters.Postgres
end
