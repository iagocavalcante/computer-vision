# ComputerVision

A self-hosted live streaming platform built with Elixir, Phoenix LiveView, and Membrane Framework. Think of it as a lightweight, open-source alternative to Twitch that you can deploy on a single VPS.

Receives RTMP streams from OBS or any streaming software, converts to HLS for browser playback, and provides real-time chat — all powered by LiveView with zero JavaScript frameworks.

## Features

- **RTMP Ingest** — Receive streams via standard RTMP protocol (port 1935)
- **HLS Playback** — Automatic conversion to HLS for browser-native playback via HLS.js
- **Real-time Chat** — Per-channel chat with emote support, rate limiting, and moderation (bans)
- **Viewer Tracking** — Live viewer counts powered by Phoenix Presence
- **Follow & Notifications** — Follow streamers and get notified when they go live
- **Categories & Search** — Organize streams by category, search across channels
- **Streamer Dashboard** — Manage stream key, channel title, category, and transcoding settings
- **Admin Panel** — Instance settings, category management, user roles
- **Auth** — Email/password registration with magic link support via Swoosh
- **Multi-quality Transcoding** — Optional per-channel transcoding with configurable concurrency limits
- **Storage Backends** — Local filesystem or S3-compatible storage
- **Dark Theme** — Clean, dark UI out of the box

## Requirements

- Elixir 1.14+
- Erlang/OTP 26+
- PostgreSQL 16+
- FFmpeg (for transcoding and thumbnails)
- pkg-config (build dependency)

## Local Development

```bash
# Install dependencies and set up database
mix setup

# Start the server
mix phx.server

# Or with IEx
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000). The first registered user automatically becomes admin.

### Streaming Locally

Point OBS or ffmpeg at the RTMP server:

**OBS:**
- Server: `rtmp://localhost:1935/live`
- Stream Key: (copy from your Dashboard at `/dashboard`)

**ffmpeg:**
```bash
ffmpeg -re -i input.mp4 -c copy -f flv rtmp://localhost:1935/live/YOUR_STREAM_KEY
```

## Deployment

### Docker Compose (Dokploy, self-hosted VPS)

```bash
# Generate a secret
mix phx.gen.secret
# or: openssl rand -base64 64

# Set environment variables and deploy
SECRET_KEY_BASE=<generated-secret> \
POSTGRES_PASSWORD=<strong-password> \
PHX_HOST=stream.yourdomain.com \
docker compose up -d
```

**Environment variables:**

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY_BASE` | Yes | — | Phoenix secret (generate with `mix phx.gen.secret`) |
| `POSTGRES_PASSWORD` | Yes | `postgres` | Database password |
| `PHX_HOST` | Yes | `localhost` | Your domain name |
| `SMTP_HOST` | No | — | SMTP server for magic link emails |
| `SMTP_PORT` | No | `587` | SMTP port |
| `SMTP_USER` | No | — | SMTP username |
| `SMTP_PASS` | No | — | SMTP password |
| `STORAGE_TYPE` | No | `local` | `local` or `s3` |
| `STORAGE_DIR` | No | `output` | Directory for HLS segments (local storage) |
| `S3_BUCKET` | No | — | S3 bucket name |
| `S3_ACCESS_KEY` | No | — | S3 access key |
| `S3_SECRET_KEY` | No | — | S3 secret key |
| `S3_REGION` | No | `us-east-1` | S3 region |
| `TRANSCODING_ENABLED` | No | `false` | Enable multi-quality transcoding |
| `MAX_CONCURRENT_TRANSCODES` | No | `2` | Max simultaneous transcodes |
| `REGISTRATION_OPEN` | No | `true` | Allow new user registration |

**Ports:** Make sure both `4000` (HTTP) and `1935` (RTMP/TCP) are accessible.

### Fly.io

```bash
# Launch the app (first time)
fly launch --no-deploy

# Set secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set SMTP_HOST=smtp.example.com SMTP_USER=you SMTP_PASS=secret

# Create a Postgres database
fly postgres create --name computervision-db
fly postgres attach computervision-db

# Allocate a public IP for RTMP
fly ips allocate-v4

# Deploy
fly deploy
```

> **Note:** RTMP on port 1935 requires a dedicated IPv4 and a `[[services]]` entry in `fly.toml` — see the included `fly.toml` for the configuration.

After deploying, streamers connect to `rtmp://your-app.fly.dev:1935/live` with their stream key.

## Architecture

```
OBS/ffmpeg → RTMP (1935) → Membrane Pipeline → HLS segments → Phoenix serves HLS → HLS.js player
                                                                    ↕
                                                            Phoenix LiveView
                                                          (chat, presence, UI)
```

**Stack:**
- **Phoenix LiveView** — All UI, no separate frontend
- **Membrane Framework** — RTMP ingest and HLS output
- **PostgreSQL** — Users, channels, categories, follows, notifications
- **Phoenix PubSub** — Real-time chat and event broadcasting
- **Phoenix Presence** — Viewer counting
- **Tailwind CSS** — Styling

**Key modules:**
- `ComputerVision.RTMPServer` — GenServer managing RTMP TCP server
- `ComputerVision.LiveStream` — Membrane Pipeline for RTMP→HLS
- `ComputerVision.Validator` — Stream key authentication
- `ComputerVision.StreamRegistry` — Tracks active stream pipelines
- `ComputerVision.NotificationWorker` — Sends go-live notifications

## Running Tests

```bash
mix test
```

## Contributing

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Run tests (`mix test`)
4. Commit your changes
5. Push to the branch and open a Pull Request

## License

MIT

## Links

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Membrane Framework](https://membrane.stream/)
- [HLS.js](https://github.com/video-dev/hls.js/)
- [Fly.io Elixir Guide](https://fly.io/docs/elixir/)
