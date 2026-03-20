import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :computer_vision, ComputerVision.Repo,
  username: "admin",
  password: "admin",
  hostname: "localhost",
  database: "computer_vision_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :computer_vision, ComputerVisionWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "uXju5j+F3kAJ6wmjSHnY4t4QuwIjIwPuYd4J9llSZMPyAWM+odnkWGjRyUmLHrdC",
  server: false

# In test we don't send emails.
config :computer_vision, ComputerVision.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Disable RTMP server in test
config :computer_vision, start_rtmp_server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
