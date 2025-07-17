#!/usr/bin/env bash

scripts_dir="$(realpath "$0" | xargs dirname)/on-song-change.d"

for n in "$scripts_dir"/*.*; do
  if [[ "$(basename "$n")" == *.disabled ]]; then
    echo "Skipping disabled script: $n" >> /tmp/rmpc-download-art.sh.log
    continue
  fi

  echo "Running script: $n" >> /tmp/rmpc-download-art.sh.log
  bash -c "$n" &
done
