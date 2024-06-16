# Borrowed from the Phoenix generator here: https://hexdocs.pm/phoenix/releases.html

ARG ELIXIR_VERSION=1.17.0
ARG OTP_VERSION=27.0
ARG ALPINE_VERSION=3.19.1

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="docker.io/library/alpine:${ALPINE_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apk add --no-cache git

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod" \
    ERL_FLAGS="+JPperf true"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV && \
    mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY lib lib

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apk add --no-cache ca-certificates git libstdc++ openssl ncurses

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod

WORKDIR "/app"
RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/ ./

USER nobody

CMD ["/app/ff_bot/bin/ff_bot", "start"]
