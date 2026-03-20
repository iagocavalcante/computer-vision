import Config

if System.get_env("PHX_SERVER") do
  config :computer_vision, ComputerVisionWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL not set"

  config :computer_vision, ComputerVision.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE not set"

  host = System.get_env("PHX_HOST", "localhost")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :computer_vision, ComputerVisionWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base

  config :computer_vision,
    rtmp_port: String.to_integer(System.get_env("RTMP_PORT", "1935")),
    rtmp_host: {0, 0, 0, 0},
    storage_backend:
      case System.get_env("STORAGE_TYPE", "local") do
        "s3" -> ComputerVision.Storage.S3
        _ -> ComputerVision.Storage.Local
      end,
    storage_dir: System.get_env("STORAGE_DIR", "output"),
    transcoding_enabled: System.get_env("TRANSCODING_ENABLED", "false") == "true",
    max_concurrent_transcodes: String.to_integer(System.get_env("MAX_CONCURRENT_TRANSCODES", "2")),
    registration_open: System.get_env("REGISTRATION_OPEN", "true") == "true"

  if System.get_env("STORAGE_TYPE") == "s3" do
    config :computer_vision, s3_bucket: System.get_env("S3_BUCKET")

    config :ex_aws,
      access_key_id: System.get_env("S3_ACCESS_KEY"),
      secret_access_key: System.get_env("S3_SECRET_KEY"),
      region: System.get_env("S3_REGION", "us-east-1")
  end

  if smtp_host = System.get_env("SMTP_HOST") do
    config :computer_vision, ComputerVision.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_host,
      port: String.to_integer(System.get_env("SMTP_PORT", "587")),
      username: System.get_env("SMTP_USER"),
      password: System.get_env("SMTP_PASS"),
      tls: :always
  end
end
