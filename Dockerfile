# syntax=docker/dockerfile:1.4
# Layer order: `flutter pub get` stays cached until pubspec.yaml / pubspec.lock / analysis_options change.
# Only `lib/`, `web/`, `.metadata` changes rerun the compile step.
# BuildKit cache mounts keep pub packages and Flutter engine/web SDK between builds (same machine).
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

ENV PUB_CACHE=/root/.pub-cache

RUN flutter config --no-analytics

COPY pubspec.yaml pubspec.lock analysis_options.yaml ./

RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

COPY .metadata ./
COPY lib/ ./lib/
COPY web/ ./web/

ARG OLLAMA_MODEL=llama3.2
RUN --mount=type=cache,target=/root/.pub-cache \
    --mount=type=cache,target=/sdks/flutter/bin/cache \
    flutter build web --release --dart-define=OLLAMA_MODEL=${OLLAMA_MODEL}

FROM nginx:1.27-alpine

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
