# Reproducible Flutter/Android build + test environment
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG FLUTTER_VERSION=3.24.0
ARG ANDROID_BUILD_TOOLS=34.0.0
ARG ANDROID_PLATFORM=android-34

ENV FLUTTER_HOME=/opt/flutter
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${FLUTTER_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${PATH}"

WORKDIR /app

# Base OS packages and build deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip \
      openjdk-17-jdk \
      clang cmake ninja-build pkg-config \
      libglu1-mesa libgtk-3-dev liblzma-dev libsqlite3-dev \
      libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

# Install Flutter SDK (stable channel matching project)
RUN curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt && \
    flutter --version && \
    flutter config --no-analytics

# Install Android SDK commandline tools + required packages
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" && \
    curl -L "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools && \
    mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" && \
    yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses && \
    sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
      "platform-tools" \
      "build-tools;${ANDROID_BUILD_TOOLS}" \
      "platforms;${ANDROID_PLATFORM}" \
      "cmdline-tools;latest" && \
    rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip

# Wire Flutter to the Android SDK and precache artifacts for faster builds/tests
RUN flutter config --android-sdk "${ANDROID_SDK_ROOT}" && \
    flutter precache --android --no-web --no-linux --no-macos --no-windows

# Cache Dart/Flutter deps early (only pubspec files)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Bring in the rest of the source
COPY . .

# Default command: format check, analyze, and run tests headlessly
CMD ["bash", "-lc", "flutter pub get && dart format --set-exit-if-changed . && dart analyze && flutter test --concurrency 1"]
