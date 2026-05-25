#!/bin/bash
# lat universal binary resolver — single source of truth for all callers.
# Resolution order:
#   1. $NPM_CONFIG_PREFIX/bin/lat  (iclaude exported env)
#   2. <script-dir>/../../npm-global/bin/lat  (relative fallback)
#   3. command -v lat  (system PATH last resort)
_lat="${NPM_CONFIG_PREFIX:+${NPM_CONFIG_PREFIX}/bin/lat}"
if [[ ! -x "$_lat" ]]; then
    _lat="$(dirname "$0")/../../npm-global/bin/lat"
fi
if [[ ! -x "$_lat" ]]; then
    _lat="$(command -v lat 2>/dev/null)"
fi
if [[ ! -x "$_lat" ]]; then
    echo "lat: binary not found (tried NPM_CONFIG_PREFIX, relative path, and PATH)" >&2
    exit 127
fi
exec "$_lat" "$@"
