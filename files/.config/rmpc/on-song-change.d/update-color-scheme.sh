#!/usr/bin/env bash

# todo - reload kitty tab colours on generating scheme

rmpc-remote () {
  rmpc remote --pid "$PID" "$@"
}

rmpc-notify () {
  [ -n "$PID" ] && rmpc-remote status "$error" --level error
}

x-log () {
  local message="$1"
  local level="${2:-INFO}"

  [ -z "$message" ] \
    && x-log "Empty message given to x-log (level $level)." ERROR \
    && return 0

  echo "[$level] $(basename "$0") | $message" >&2

  if [ "$level" = "ERROR" ]; then
    rmpc-notify "$message" "$(printf '%s\n' "${level,,}")"
  fi
}

type slugify &>/dev/null || source "$HOME"/.zshrc.d/01-dependency-functions.zshrc

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'on_exit $? $LINENO' EXIT
on_exit() { [ $1 -ne 0 ] && x-log "Failed command (code $1) on line $2: '${last_command}'" ERROR && exit $2; }

x-log "Starting update-color-scheme script."

config_dir="$HOME"/.config/rmpc
cache_dir="$HOME"/.cache/rmpc

art_dir="$cache_dir"/art
status_file="$cache_dir"/current_album
prefs_file="$config_dir"/on-song-change.json

default_art_file="$HOME"/Pictures/full.png

backends=()
global_used_backend='<NULL>'

init-prefs () {
  if [ ! -f "$prefs_file" ]; then
    x-log "Preferences file not found, creating default preferences file at '$prefs_file'."
    jq -n '{ "backends": {}, "backend-strategy": "random" }' > "$prefs_file"
  fi
}

get-pref () {
  local root_pref='.update_color_scheme'
  local value_pref="$1"

  if [[ "$value_pref" =~ ^\\. ]]; then
    x-log "Invalid preference path '$value_pref'; must start with a dot."
    exit $LINENO
  fi

  local json_path="${root_pref}${value_pref}"

  x-log "Retrieving preference at '${json_path}' from '$prefs_file'."
  cat "$prefs_file" | jq -c "$json_path"
}

get-backend-pref () {
  local album_slug="$(slugify "$ALBUM")"
  local artist_slug="$(slugify "$ALBUMARTIST")"
  local value
  local backends=()

  value="$(get-pref ".backend.override.${artist_slug}.${album_slug}")"
  x-log "Value: $value"

  if [[ "$value" == 'null' ]]; then
    # no override, use global preference
    backends=("$(get-pref '.backend.default' | jq -r '.[]')")
  elif [[ "$value" =~ ^\".*\"$ ]]; then
    # is string
    backends+=("$(echo "$value" | jq -r '.')")
  elif [[ "$value" =~ ^\[.*\]$ ]]; then
    # is array
    readarray -t backends <<< "$(echo "$value" | jq -r '.[]')"
  else
    x-log "Invalid backend preference format for '$artist_slug/$album_slug', expected string or array, got: '$value'" ERROR
    return $LINENO
  fi

  echo "${backends[@]}"
}

get-backend-strategy-pref () {
  get-pref '.backend.strategy' | jq -r '.'
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
  local art_file="$art_dir/$(slugify "$ALBUMARTIST")/$(slugify "$ALBUM")"

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
  local mode=''
  local new_backends
  local backend

  echo "WAL_BACKEND = '$WAL_BACKEND'"

  if [ -n "$WAL_BACKEND" ]; then
    x-log "WAL_BACKEND is set to '$WAL_BACKEND', using that as the only backend."
    backends=("$WAL_BACKEND")
  else
    backends=($(get-backend-pref))
  fi

  x-log "Got backend preference: '$(echo "${backends[@]}")'."

  if [ "${#backends[@]}" -gt 0 ]; then
    x-log "Using preferred backend from config."
  else
    x-log "No backend preference found, exiting." ERROR
    exit $LINENO
  fi

  mode="$(get-pref '.mode' '' | jq -r '.')"
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

    wal_output="$(wal -ne$mode -i "$art_file" --backend="$b")"
    wal_code=$?

    # `wal` must be run with the `-e` flag to ensure it doesn't interfere with rmpc
    if [ $wal_code -eq 0 ]; then
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

  rmpc-remote set theme "${config_dir}/themes/${theme}.ron" > /tmp/rmpc.reload-rmpc.txt 2>&1
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
    echo "ARTIST=$ALBUMARTIST"
    echo "ALBUM=$ALBUM"
    echo "BACKEND=$global_used_backend"
  } > "$status_file"

  x-log "Set previous album info in status file '${status_file}'"
}

is-new-album () {
  [ ! -f "$status_file" ] && return 0

  grep -qiE "^ARTIST=$ALBUMARTIST" "$status_file" && \
  grep -qiE "^ALBUM=$ALBUM" "$status_file" && \
    return 1

  return 0
}

main () {
  if ! is-new-album; then
    x-log "No new album detected, skipping theme update."
    return 0
  fi

  init-prefs
  art_file="$(extract-art-where-missing)"
  generate-scheme "$art_file"
  set-previous-album
  reload-rmpc
  reload-pywalfox
  reload-plasma
  x-log "Theme set successfully."
}

set -e
main
set +e
