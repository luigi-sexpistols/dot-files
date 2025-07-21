#!/usr/bin/env sh

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'on_exit $? $LINENO' EXIT
on_exit() { [ $1 -ne 0 ] && x-log "Failed command (code $1) on line $2: '${last_command}'"; }

home_dir='/home/ashley'
config_dir="$home_dir"/.config/rmpc
art_dir="$home_dir"/.cache/rmpc/art

default_art_file="$home_dir"/Pictures/full.png

slugify () {
    echo "$1" | \
        sed -E 's/ & / and /g' | \
        sed -E 's/[^a-zA-Z0-9]/_/g' | \
        sed -E 's/_{2,}/_/g' | \
        sed -E 's/^_//g' | \
        tr '[:upper:]' '[:lower:]'
}

art_file="$art_dir/$(slugify "$ARTIST")/$(slugify "$ALBUM")"

if [ ! -f "$art_file" ]; then
    mkdir -p "$(dirname "$art_file")"

    if ! rmpc albumart --output "$art_file"; then
        art_file="$default_art_file"
    fi
fi

x-log "Using album art file: $art_file"

# try each backend until one succeeds; we prefer the schemes `colorz` generates, but fall back to `wal` in rare cases
for b in colorz wal; do
  x-log "Trying color scheme update with backend '$b'"

  # `wal` must be run with the `-e` flag to ensure it doesn't interfere with rmpc
  if wal -ne -i "${art_file}" --backend="$b"; then
    x-log "Color scheme updated using backend '$b'"
    break
  fi
done

# reload theme
theme="$(cat "$config_dir"/config.ron | grep 'theme' | grep -Eo '"[^"]+"' | grep -Eo '[^"]+')"
x-log "Theme to set: ${theme} @ ${config_dir}/themes/${theme}.ron"

if rmpc remote set theme "${config_dir}/themes/${theme}.ron"; then
  pywalfox update
  x-log "Theme '${theme}' set successfully."
else
  error="Failed to set theme '${theme}'."
  x-log "$error" ERROR
  rmpc remote --pid "$PID" status "$error" --level error
fi
