#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Set same default compilation flags as abuild.
export CFLAGS="-Os -fomit-frame-pointer"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="$CFLAGS"
export LDFLAGS="-fuse-ld=mold -Wl,--strip-all -Wl,--as-needed"

export CC=xx-clang
export CXX=xx-clang++

log() {
    echo ">>> $*"
}

DEBUG_BUILD=false

AUDACIOUS_URL="$1"
AUDACIOUS_PLUGINS_URL="$2"

if [ -z "$AUDACIOUS_URL" ]; then
    log "ERROR: Audacious URL missing."
    exit 1
fi

if [ -z "$AUDACIOUS_PLUGINS_URL" ]; then
    log "ERROR: Audacious plugins URL missing."
    exit 1
fi

#
# Install required packages.
#
apk --no-cache add \
    curl \
    build-base \
    mold \
    llvm \
    clang \
    meson \
    abuild \
    pkgconf \
    qt6-qtbase-dev \

xx-apk --no-cache --no-scripts add \
    musl-dev \
    gcc \
    g++ \
    qt6-qtbase-dev \
    qt6-qtsvg-dev \
    libxml2-dev \
    curl-dev \
    faad2-dev \
    ffmpeg-dev \
    flac-dev \
    fluidsynth-dev \
    lame-dev \
    libcddb-dev \
    libcdio-dev \
    libcdio-paranoia-dev \
    libcue-dev \
    libmms-dev \
    libnotify-dev \
    libogg-dev \
    libopenmpt-dev \
    libsamplerate-dev \
    libsndfile-dev \
    libvorbis-dev \
    libxcomposite-dev \
    mpg123-dev \
    neon-dev \
    opusfile-dev \
    pulseaudio-dev \
    wavpack-dev \

# Make sure tools used to generate code are the ones from the host.
if  xx-info is-cross; then
    for bin in moc uic rcc lrelease; do
        ln -sf /usr/lib/qt6/libexec/$bin $(xx-info sysroot)usr/lib/qt6/libexec/$bin
    done
fi

# Create the meson cross compile file.
echo "[binaries]
pkg-config = '$(xx-info)-pkg-config'
strip = '$(xx-info)-strip'

[properties]
sys_root = '$(xx-info sysroot)'
pkg_config_libdir = [ '$(xx-info sysroot)usr/lib/pkgconfig', '$(xx-info sysroot)usr/share/pkgconfig' ]

[host_machine]
system = 'linux'
cpu_family = '$(xx-info arch)'
cpu = '$(xx-info arch)'
endian = 'little'
" > /tmp/meson-cross.txt

#
# Download sources.
#

log "Downloading Audacious package..."
mkdir /tmp/audacious
mkdir /tmp/audacious-plugins
curl -# -L -f ${AUDACIOUS_URL} | tar xj --strip 1 -C /tmp/audacious
curl -# -L -f ${AUDACIOUS_PLUGINS_URL} | tar xj --strip 1 -C /tmp/audacious-plugins

#
# Compile Audacious.
#

log "Configuring Audacious..."
(
    cd /tmp/audacious && abuild-meson \
        -Db_lto=true \
        -Ddbus=false \
        -Dgtk=false \
        -Dqt=true \
        -Dbuildstamp="alpine-linux" \
        --cross-file /tmp/meson-cross.txt \
        . build
)

if $DEBUG_BUILD; then
    echo "***************************************"
    cat /tmp/audacious/build/meson-logs/meson-log.txt
    echo "***************************************"
fi

log "Compiling Audiacious..."
meson compile -C /tmp/audacious/build

log "Installing Audacious..."
DESTDIR=/tmp/audacious-install meson install --no-rebuild -C /tmp/audacious/build
DESTDIR=$(xx-info sysroot) meson install --no-rebuild -C /tmp/audacious/build

log "Configuring Audacious plugins..."
(
    qtgl=true
    case "$(xx-info arch)" in
        arm|arm64)
            qtgl=false
            ;;
    esac

    # shared-mime-info.pc is under /usr/share/pkgconfig.
    cd /tmp/audacious-plugins &&
    PKG_CONFIG_PATH=$(xx-info sysroot)usr/share/pkgconfig abuild-meson \
        -Db_lto=true \
        -Dgtk=false \
        -Dqt=true \
        -Dalsa=false \
        -Djack=false \
        -Doss=false \
        -Dpipewire=false \
        -Dsdlout=false \
        -Dsndio=false \
        -Dgl-spectrum=$qtgl \
        --cross-file /tmp/meson-cross.txt \
        . build
)

if $DEBUG_BUILD; then
    echo "***************************************"
    cat /tmp/audacious-plugins/build/meson-logs/meson-log.txt
    echo "***************************************"
fi

log "Compiling Audiacious plugins..."
meson compile -C /tmp/audacious-plugins/build

log "Installing Audacious plugins..."
DESTDIR=/tmp/audacious-plugins-install meson install --no-rebuild -C /tmp/audacious-plugins/build
