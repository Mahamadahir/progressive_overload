# Flutter + Dart 3.8 CI/development container
FROM ghcr.io/cirruslabs/flutter:3.24.0

WORKDIR /app

# Base tooling and Flutter cache
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgtk-3-dev liblzma-dev clang cmake ninja-build pkg-config \
    && rm -rf /var/lib/apt/lists/* \
    && flutter config --enable-web --no-analytics \
    && flutter precache

# Copy manifests first to leverage Docker layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source
COPY . .

# Default command: format check, analyze, and test (single worker for CI stability)
CMD ["bash", "-lc", "flutter pub get && dart format --set-exit-if-changed . && dart analyze && flutter test --concurrency 1"]
