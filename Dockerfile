#
# audacious Dockerfile
#
# https://github.com/jlesage/docker-audacious
#

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=

# Define software versions.
ARG AUDACIOUS_VERSION=4.5.1

# Define software download URLs.
ARG AUDACIOUS_URL=http://distfiles.audacious-media-player.org/audacious-${AUDACIOUS_VERSION}.tar.bz2
ARG AUDACIOUS_PLUGINS_URL=http://distfiles.audacious-media-player.org/audacious-plugins-${AUDACIOUS_VERSION}.tar.bz2

# Get Dockerfile cross-compilation helpers.
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Build Audacious.
FROM --platform=$BUILDPLATFORM alpine:3.20 AS audacious
ARG TARGETPLATFORM
ARG AUDACIOUS_URL
ARG AUDACIOUS_PLUGINS_URL
COPY --from=xx / /
COPY src/audacious /build
RUN /build/build.sh "$AUDACIOUS_URL" "$AUDACIOUS_PLUGINS_URL"
RUN xx-verify \
    /tmp/audacious-install/usr/bin/audacious

# Pull base image.
FROM jlesage/baseimage-gui:alpine-3.20-v4.12.3

ARG AUDACIOUS_VERSION
ARG DOCKER_IMAGE_VERSION

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN add-pkg \
        qt6-qtbase-x11 \
        libnotify \
        mesa-dri-gallium \
        # For optical drive detection.
        lsscsi \
        # Audio codecs.
        faad2-libs \
        fluidsynth-libs \
        ffmpeg-libavcodec \
        ffmpeg-libavformat \
        libcddb \
        libcdio \
        libcdio-paranoia \
        libcue \
        libflac \
        libmms \
        libpulse \
        libsamplerate \
        libsndfile \
        neon \
        opusfile \
        wavpack-libs \
        # For dark mode.
        adwaita-qt6 \
        # For proper display of icons.
        qt6-qtsvg \
        # A font is needed.
        font-croscore

# Generate and install favicons.
RUN \
    APP_ICON_URL=https://raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/audacious-icon.png && \
    install_app_icon.sh "$APP_ICON_URL"

# Add files.
COPY rootfs/ /
COPY --from=audacious /tmp/audacious-install /
COPY --from=audacious /tmp/audacious-plugins-install /

# Set internal environment variables.
RUN \
    set-cont-env APP_NAME "Audacious" && \
    set-cont-env APP_VERSION "$AUDACIOUS_VERSION" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    true

# Set public environment variables.
ENV \
    WEB_AUDIO=1

# Define mountable directories.
VOLUME ["/storage"]

# Metadata.
LABEL \
      org.label-schema.name="audacious" \
      org.label-schema.description="Docker container for Audacious" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-unknown}" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-audacious" \
      org.label-schema.schema-version="1.0"
