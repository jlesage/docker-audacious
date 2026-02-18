#!/bin/sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

if is-bool-val-false "${WEB_AUDIO:-0}"; then
    echo "ERROR: Web audio support must be enabled via the WEB_AUDIO environment variable."
    exit 1
fi

# vim:ft=sh:ts=4:sw=4:et:sts=4
