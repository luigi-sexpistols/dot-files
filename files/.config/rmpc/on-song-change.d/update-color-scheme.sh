#!/usr/bin/env bash

# todo - reload kitty tab colours on generating scheme

x-log () {
  echo "[${2:-INFO}] $1" >&2

  if [ -n "$2" ] && [ "$2" = "ERROR" ]; then
    rmpc remote --pid "$PID" status "$1" --level "$(printf '%s\n' "${2,,}")"
  fi
}

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
#trap 'on_exit $? $LINENO' ERR
trap 'on_exit $? $LINENO' ERR
on_exit() { [ $1 -ne 0 ] && x-log "Failed command (code $1) on line $2: '${last_command}'" ERROR; }

x-log "Starting update-color-scheme script."

config_dir="$HOME"/.config/rmpc
cache_dir="$HOME"/.cache/rmpc

art_dir="$cache_dir"/art
current_art_file="$cache_dir"/current_art
status_file="$cache_dir"/current_album
prefs_file="$config_dir"/on-song-change.json

default_art_file="$HOME"/Pictures/full.png

declare global_used_backend='<NULL>'

slugify () {
  echo "$1" \
  | sed -E 's/ & / and /g' \
  | sed -E 's/[^a-zA-Z0-9]/_/g' \
  | sed -E 's/_{2,}/_/g' \
  | sed -E 's/^_//g' \
  | sed -E 's/_$//g' \
  | tr '[:upper:]' '[:lower:]'
}

init-prefs () {
  if [ ! -f "$prefs_file" ]; then
    x-log "Preferences file not found, creating default preferences file at '$prefs_file'."
    jq -n '{ "backends": {}, "backend-strategy": "random" }' > "$prefs_file"
  fi
}

get-pref () {
  x-log "Retrieving preference at '$1' from '$prefs_file'."
  cat "$prefs_file" | jq -r "$1"
}

get-backend-pref () {
  local album_slug="$(slugify "$ALBUM")"
  local artist_slug="$(slugify "$ARTIST")"

  get-pref ".backend.override.\"${artist_slug}/${album_slug}\""
}

get-backend-strategy-pref () {
  get-pref '.backend.strategy'
}

get-backend () {
  case "$(get-backend-strategy-pref)" in
    'random')
      echo "${backends[RANDOM % ${#backends[@]}]}"
      ;;
    'first')
      echo "${backends[0]}"
      ;;
  esac
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
  local backend_pref=''
  local mode=''
  local backends=()
  local backend

  backend_pref="$(get-backend-pref)"

  x-log "Got backend preference: '$backend_pref'."

  if [ -n "$backend_pref" ] && [ "$backend_pref" != "null" ]; then
    backends=("$backend_pref")
    x-log "Using preferred backend '$backend_pref'."
  else
    backends=(wal colorz colorthief haishoku)
    x-log "No preferred backend set, using default backends."
  fi

  mode="$(get-pref '.mode' '')"
  x-log "Got mode preference: '$mode'."

  if [ -n "$mode" ] && [ "$mode" != "null" ]; then
    x-log "Using preferred mode '$mode'."
  else
    mode=''
    x-log "No preferred mode set, using '' (dark)."
  fi

  # try each backend until one succeeds
  while true; do
    [ ${#backends[@]} -eq 0 ] && \
      x-log 'No backends left to try, exiting.' && \
      return 1

    b="$(get-backend)"

    new_backends=()
    for item in "${backends[@]}"; do
      if [[ "$item" != "$b" ]]; then
        new_backends+=("$item")
      fi
    done
    backends=("${new_backends[@]}")

    x-log "Trying color scheme update with backend '$b'."

    # `wal` must be run with the `-e` flag to ensure it doesn't interfere with rmpc
    if wal -ne$mode -i "$art_file" --backend="$b" > /dev/null 2>&1; then
      global_used_backend="$b"
      x-log "Color scheme updated."
      break
    else
      x-log "$wal_output" ERROR
    fi
  done
}

reload-rmpc () {
  local theme="$(cat "$config_dir"/config.ron | grep 'theme' | grep -Eo '"[^"]+"' | grep -Eo '[^"]+')"

  rmpc remote --pid "$PID" set theme "${config_dir}/themes/${theme}.ron" > /tmp/rmpc.reload-rmpc.txt 2>&1
  x-log "Reloaded rmpc theme"
}

reload-pywalfox () {
  pywalfox update > /tmp/rmpc.reload-pywalfox.txt 2>&1
  x-log "Reloaded Firefox theme"
}

reload-plasma () {
  # unset and set the pywal colorscheme to ensure it reloads
  for scheme in BreathDark Pywal; do
    plasma-apply-colorscheme "$scheme" > /tmp/rmpc.reload-plasma.txt 2>&1
  done

  x-log "Reloaded Plasma colorscheme"
}

set-previous-album () {
  {
    echo "ARTIST=$ARTIST"
    echo "ALBUM=$ALBUM"
    echo "BACKEND=$global_used_backend"
  } > "$status_file"

  x-log "Set previous album info in status file '${status_file}'"
}

is-new-album () {
  grep -qiE "^ARTIST=$ARTIST" "$status_file" && \
  grep -qiE "^ALBUM=$ALBUM" "$status_file" && \
    return 1

  return 0
}

main () {
  is-new-album || {
    x-log "No new album detected, skipping theme update."
    exit 0
  }

  if (
    init-prefs && \
    art_file="$(extract-art-where-missing)" && \
    generate-scheme "$art_file" && \
    set-previous-album && \
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
}

main
