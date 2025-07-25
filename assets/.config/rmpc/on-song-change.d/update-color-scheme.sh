#!/usr/bin/env bash

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'on_exit $? $LINENO' EXIT
on_exit() { [ $1 -ne 0 ] && x-log "Failed command (code $1) on line $2: '${last_command}'"; }

# todo - make this more generic so anyone can use it
home_dir='/home/ashley'
config_dir="$home_dir"/.config/rmpc
art_dir="$home_dir"/.cache/rmpc/art

# set mode to either '' (dark) and 'l' (light)
mode=''

default_art_file="$home_dir"/Pictures/full.png

slugify () {
    echo "$1" | \
        sed -E 's/ & / and /g' | \
        sed -E 's/[^a-zA-Z0-9]/_/g' | \
        sed -E 's/_{2,}/_/g' | \
        sed -E 's/^_//g' | \
        tr '[:upper:]' '[:lower:]'
}

extract-art-where-missing () {
  local art_file="$art_dir/$(slugify "$ARTIST")/$(slugify "$ALBUM")"

  # if the art file doesn't exist, pull it from rmpc
  if [ ! -f "$art_file" ]; then
      mkdir -p "$(dirname "$art_file")"

      if ! rmpc albumart --output "$art_file"; then
          x-log "Failed to extract album art, using default art file."
          art_file="$default_art_file"
      fi
  fi

  x-log "Using album art file: $art_file"

  echo "$art_file"
}

generate-scheme () {
  local art_file="$1"

  # try each backend until one succeeds; we prefer the schemes `colorz` generates, but fall back to `wal` in rare cases
  for b in colorz wal; do
    x-log "Trying color scheme update with backend '$b'"

    # `wal` must be run with the `-e` flag to ensure it doesn't interfere with rmpc
    if wal -ne$mode -i "$art_file" --backend="$b"; then
      x-log "Color scheme updated using backend '$b'"
      break
    fi
  done
}

reload-rmpc () {
  local theme="$(cat "$config_dir"/config.ron | grep 'theme' | grep -Eo '"[^"]+"' | grep -Eo '[^"]+')"

  rmpc remote set theme "${config_dir}/themes/${theme}.ron"
  x-log "Reloaded rmpc theme"
}

reload-pywalfox () {
  pywalfox update
  x-log "Reloaded Firefox theme"
}


reload-plasma () {
  # unset and set the pywal colorscheme to ensure it reloads
  for scheme in BreathDark Pywal; do
    plasma-apply-colorscheme "$scheme"
  done

  x-log "Reloaded Plasma colorscheme"
}

# todo - regenerate scheme on artwork change only (restrict annoying beep to album switch)

if (
	art_file="$(extract-art-where-missing)" && \
  generate-scheme "$art_file" && \
  reload-rmpc && \
  reload-pywalfox && \
  reload-plasma \
); then
  x-log "Theme set successfully."
else
  error="Failed to set theme."
  x-log "$error" ERROR
  rmpc remote --pid "$PID" status "$error" --level error
fi
