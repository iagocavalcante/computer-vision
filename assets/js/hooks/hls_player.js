const HlsPlayer = {
  mounted() {
    this.loadHls().then(() => this.initPlayer());
  },

  loadHls() {
    if (window.Hls) return Promise.resolve();

    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = "https://cdn.jsdelivr.net/npm/hls.js@1.5.17";
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  },

  initPlayer() {
    const video = this.el;
    const src = video.dataset.streamUrl;
    const Hls = window.Hls;

    if (Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        maxBufferLength: 1,
        liveBackBufferLength: 0,
        liveSyncDuration: 1,
        liveMaxLatencyDuration: 5,
        liveDurationInfinity: true,
        highBufferWatchdogPeriod: 1,
      });
      hls.attachMedia(video);
      hls.on(Hls.Events.MEDIA_ATTACHED, () => {
        hls.loadSource(src);
      });
      this.hls = hls;
    } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
      video.src = src;
    }
  },

  destroyed() {
    if (this.hls) {
      this.hls.destroy();
    }
  },
};

export default HlsPlayer;
