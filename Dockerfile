# Слои: pub get кэшируется Docker, пока не меняются pubspec / lock / analysis_options;
# компиляция перезапускается при изменении lib/, web/, .metadata.
# Для ускорения локально: DOCKER_BUILDKIT=1 docker compose build (опционально).
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

ENV PUB_CACHE=/root/.pub-cache

RUN flutter config --no-analytics

COPY pubspec.yaml pubspec.lock analysis_options.yaml ./

RUN flutter pub get

COPY .metadata ./
COPY lib/ ./lib/
COPY web/ ./web/

# Веб-реализация sqflite грузит shared worker и wasm из корня сайта; без этого — 404 и белый экран.
RUN dart run sqflite_common_ffi_web:setup

ARG OLLAMA_MODEL=llama3.2
RUN flutter build web --release --dart-define=OLLAMA_MODEL=${OLLAMA_MODEL}

FROM nginx:1.27-alpine

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
