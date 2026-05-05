# Multi-stage frontend image: Flutter web build → nginx static serve.
# The MORA_KNODE_API base URL is baked at build time via --dart-define
# (Flutter web's String.fromEnvironment is compile-time). Override it
# per-environment with the build arg when calling docker compose build.

FROM ghcr.io/cirruslabs/flutter:stable AS build
ARG MORA_KNODE_API=http://localhost:5163
WORKDIR /src
COPY src/frontend/pubspec.yaml src/frontend/pubspec.lock ./
RUN flutter pub get
COPY src/frontend/. ./
RUN flutter build web --release \
    --dart-define=MORA_KNODE_API=${MORA_KNODE_API}

FROM nginx:alpine
COPY --from=build /src/build/web /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
