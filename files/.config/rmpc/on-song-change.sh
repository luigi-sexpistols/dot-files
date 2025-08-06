#!/usr/bin/env bash

scripts_dir="$(realpath "$0" | xargs dirname)/on-song-change.d"

enable_logging="true"
log_file=/tmp/rmpc.on-song-change.log

x-log () {
  [ "$enable_logging" != "true" ] && return 0

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

  [ "$level" = "ERROR" ] && rmpc remote --pid "$PID" status "$message" --level "$(printf '%s\n' "${level,,}")"
  echo "[${level}] ${current_script} | ${message}" >> "$log_file"
}

# make the x-log function available to subshells
export -f x-log

x-log "ARTIST: $ARTIST"
x-log " ALBUM: $ALBUM"
x-log " TITLE: $TITLE"

for n in "$scripts_dir"/*.*; do
  if [[ "$(basename "$n")" == *.disabled ]]; then
    x-log "Skipping disabled script: $(dirname $n | xargs basename)/$(basename $n)"
    continue
  fi

  x-log "Running script: $(dirname $n | xargs basename)/$(basename $n)"

  output="$("$n" 2>&1)"
  exit_code=$?

  echo "$output" >> "$log_file"

  if [ $exit_code -ne 0 ]; then
    x-log "Script failed (${exit_code}): $(dirname $n | xargs basename)/$(basename $n)" ERROR
  else
    x-log "Script succeeded (${exit_code}): $(dirname $n | xargs basename)/$(basename $n)"
  fi
done

x-log 'Completed on-song-change script execution.'
x-log '----------------------------------------'
