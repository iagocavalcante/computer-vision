# ComputerVision

A Phoenix application for live video streaming using Membrane Framework. Receives RTMP streams and converts them to HLS for browser playback, with real-time chat via Phoenix LiveView.

## Features

  * RTMP ingest via Membrane Framework
  * HLS (HTTP Live Streaming) output for browser playback
  * Live stream viewer with HLS.js player
  * Real-time chat via Phoenix PubSub and LiveView
  * Stream key validation

## Setup

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Streaming

Send an RTMP stream to `rtmp://<host>:1935` using OBS or ffmpeg:

```bash
ffmpeg -re -i input.mp4 -c copy -f flv rtmp://localhost:1935/live/username_streamkey
```

## Learn more

  * Phoenix: https://www.phoenixframework.org/
  * Membrane Framework: https://membrane.stream/
