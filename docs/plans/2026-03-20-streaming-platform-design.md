# ComputerVision — Self-Hosted Live Streaming Platform

## Vision

A multi-tenant live streaming platform built with Phoenix LiveView and Membrane Framework. Ships as a Docker Compose stack. Anyone can run their own Twitch-like service on a single VPS or scale horizontally.

## Architecture Overview

**Core components:**

- **Phoenix LiveView app** — all UI, auth, chat, real-time features. No separate frontend.
- **Membrane pipelines** — one per active stream. RTMP ingest → HLS output. DynamicSupervisor manages lifecycle.
- **Postgres** — users, channels, categories, follows, stream metadata.
- **Redis (Redix)** — PubSub for chat across nodes, viewer count tracking. Optional in single-node.
- **Local disk or S3-compatible storage** — HLS segments on disk by default, S3/MinIO for distributed setups.

**Key decisions:**

- No SPA. LiveView handles everything. Only client-side JS is HLS.js for video playback.
- One BEAM node = fully functional. Add nodes behind a load balancer to scale.
- Streams are ephemeral. HLS segments cleaned up after stream ends. No VOD in v1.
- Tailwind CSS with dark theme by default.

## Data Model

### Users & Auth

- `users` — email, hashed_password, username (unique), display_name, avatar_url, bio, stream_key (UUID, regeneratable), role (streamer/admin), confirmed_at
- `users_tokens` — magic link tokens, session tokens (standard phx.gen.auth)

Auth: email/password + magic link (passwordless). Generated via `mix phx.gen.auth`.

### Streaming

- `channels` — belongs_to user (1:1), title, category_id, is_live (boolean), started_at, viewer_count, thumbnail_url, transcoding_enabled (boolean)
- `categories` — name, slug, icon_url, parent_category_id (subcategories)

### Social

- `follows` — follower_id, streamer_id, unique constraint, inserted_at
- `notifications` — user_id, type (streamer_went_live, etc.), payload (jsonb), read_at

### Chat

- Messages are **not persisted**. Flow through PubSub, exist only during live stream.
- `emotes` — name, code (e.g., `:hype:`), image_url, channel_id (null = global)
- `chat_bans` — channel_id, user_id, reason, expires_at

### Admin

- `instance_settings` — key/value store for instance-wide config (site name, registration, transcoding defaults)

## Streaming Pipeline

### RTMP Ingest

1. Streamer connects: `rtmp://host:1935/live/{username}_{stream_key}`
2. `Validator` protocol authenticates stream key against DB
3. `Membrane.Pipeline` started under `DynamicSupervisor`
4. PubSub broadcasts `{:streamer_went_live, channel}` → notifications to followers

### HLS Output (no transcoding — default)

- Source → demux audio/video → SinkBin writes HLS segments to `output/{user_id}/live/`
- Single quality passthrough. Minimal CPU.

### HLS Output (with transcoding — opt-in)

- Source → demux → FFmpeg transcoding element spawns FFmpeg process
- Produces multiple renditions: source + configured lower qualities (720p, 480p)
- Each rendition gets its own segment directory
- Master `index.m3u8` references all renditions for adaptive bitrate
- Gated by per-channel toggle + instance-wide `max_concurrent_transcodes`

### Viewer Delivery

- Single node: segments served by Phoenix (Plug.Static or controller)
- Multi node: segments to shared storage (S3/MinIO), served via CDN or direct URL

### Cleanup

- Stream ends → cleanup task removes HLS segments after 30s grace period

## LiveView Pages

### Public (no auth)

- `/` — Directory. Grid of live channels sorted by viewer count. Category filter. Search.
- `/categories` — Browse categories, click into one to see live streams.
- `/c/:username` — Channel page. HLS player, chat, streamer info, follow button. Offline state when not live.

### Authenticated

- `/dashboard` — Stream key, status, toggle transcoding, set title/category. Quick stats.
- `/dashboard/emotes` — Manage channel emotes.
- `/settings` — Profile settings (display name, avatar, bio, email, password).
- `/following` — Followed streamers with live indicators.

### Admin

- `/admin` — Instance settings (site name, registration, max transcodes, SMTP).
- `/admin/categories` — CRUD categories.
- `/admin/users` — User management, role assignment.
- `/admin/emotes` — Global emotes.

## Real-time Features

### Chat

- PubSub topic per channel: `chat:{channel_id}`
- Messages: `%{sender, content, emotes, timestamp}` — broadcast only, never persisted
- Emote parsing client-side. Raw text in, `<img>` tags rendered in LiveView.
- Rate limiting: 3 messages/second per user, enforced in LiveView process.
- Moderation: channel owner bans users (persisted), banned users blocked from sending.

### Viewer Count

- Phoenix Presence per channel: `presence:{channel_id}`
- Mount joins, disconnect leaves automatically.
- Debounced updates every 5s to directory page.

### Notifications

- Stream starts → query followers → insert notification rows → broadcast to online followers
- Online: LiveView toast in real-time. Offline: unread badge on next login.

## Horizontal Scaling

- **Single node (default)**: PubSub local Erlang, Presence in-memory.
- **Multi node**: `Phoenix.PubSub.Redis` adapter. Presence syncs via CRDT. `libcluster` for node discovery.
- RTMP port (1935) needs TCP load balancer (HAProxy) to distribute across nodes.

## Docker Compose & Self-Hosting

### Stack

```
computer-vision-app   — Elixir release, port 4000 (HTTP) + 1935 (RTMP)
computer-vision-db    — Postgres 16, persistent volume
computer-vision-redis — Redis 7, PubSub (optional single-node)
```

### Environment Variables

- `DATABASE_URL`, `SECRET_KEY_BASE` — standard Phoenix
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` — magic link emails
- `RTMP_HOST`, `RTMP_PORT` — RTMP binding (default `0.0.0.0:1935`)
- `STORAGE_TYPE` — `local` (default) or `s3`
- `S3_BUCKET`, `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` — for S3/MinIO
- `TRANSCODING_ENABLED` — instance default toggle
- `TRANSCODING_QUALITIES` — e.g., `720p,480p`
- `MAX_CONCURRENT_TRANSCODES` — server capacity limit
- `REGISTRATION_OPEN` — open/closed registration

### Setup

1. Clone repo, copy `.env.example` to `.env`, fill in SMTP + secret
2. `docker compose up -d`
3. Visit `http://localhost:4000`, first registered user becomes admin
4. Configure from `/admin`

### Elixir Release

- Multi-stage Dockerfile: build (compile + digest assets) → runtime (slim Debian)
- Migrations: `docker exec app bin/computer_vision eval "ComputerVision.Release.migrate"`

## V1 Scope Summary

**In scope:** Auth (email/magic link), RTMP ingest, HLS playback, live chat with emotes, viewer count, categories/tags, follow/notify, optional multi-quality transcoding, streamer dashboard, admin panel, Docker Compose deployment, dark theme UI.

**Deferred:** VOD replay, OAuth providers, Kubernetes/Helm, CDN integration, stream recording, donations/subscriptions, clip creation.
