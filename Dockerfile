# Build stage
FROM hexpm/elixir:1.16.1-erlang-26.2.2-debian-bookworm-20240130 AS build

RUN apt-get update -y && apt-get install -y build-essential git npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY assets assets
COPY config config
COPY lib lib
COPY priv priv

RUN mix assets.deploy
RUN mix compile
RUN mix release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ffmpeg \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

COPY --from=build --chown=nobody:root /app/_build/prod/rel/computer_vision ./

USER nobody

EXPOSE 4000 1935

CMD ["bin/computer_vision", "start"]
