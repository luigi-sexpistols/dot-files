#!/usr/bin/env bash

scripts_dir="$(realpath "$0" | xargs dirname)/on-song-change.d"

enable_logging="true"

x-log () {
  [ "$enable_logging" != "true" ] && return 0

  local log_file=/tmp/rmpc.on-song-change.log
  local log_dir="$(dirname "$log_file")"

  local message="$1"
  local level="$2"
  local current_script="$(basename "$0")"

  if [ -z "$level" ]; then
    level="INFO"
  fi

  if [ -z "$message" ]; then
    message="$level"
    level="INFO"
  fi

  [ ! -d "$log_dir" ] && mkdir -p "$log_dir"
  [ ! -f "$log_file" ] && touch "$log_file"

  echo "[${level}] ${current_script} | ${message}" >> "$log_file"
}

# make the x-log function available to subshells
export -f x-log

x-log "ARTIST $ARTIST"
x-log " ALBUM $ALBUM"
x-log " TITLE $TITLE"

for n in "$scripts_dir"/*.*; do
  if [[ "$(basename "$n")" == *.disabled ]]; then
    x-log "Skipping disabled script: $n"
    continue
  fi

  x-log "Running script: $n"

  bash -c "$n" &
done
