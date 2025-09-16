#!/bin/env bash

get-override-pref () {
  local root_pref='.lyrics.override'
  local value_pref="$1"

  if [[ "$value_pref" =~ ^\\. ]]; then
    x-log "Invalid preference path '$value_pref'; must start with a dot."
    exit $LINENO
  fi

  local json_path="${root_pref}${value_pref}"

  x-log "Retrieving preference at '${json_path}' from '$prefs_file'."
  cat "$prefs_file" | jq -c "$json_path"
}

echo "HAS_LRC: $HAS_LRC" >&2
echo "LRC_FILE: $LRC_FILE" >&2

config_dir="$HOME"/.config/rmpc
prefs_file="$config_dir"/on-song-change.json

type slugify &>/dev/null || source "$HOME"/.zshrc.d/01-dependency-functions.zshrc

if [ "$HAS_LRC" = "false" ]; then
  mkdir -p "$(dirname "$LRC_FILE")"

  prefs_artist="$(slugify "$ARTIST")"
  prefs_album="$(slugify "$ALBUM")"

  overrides="$(get-override-pref ".[\"$prefs_artist\"][\"$prefs_album\"]")"
  artist_override="$(echo "$overrides" | jq -r ".artist // \"$ARTIST\"")"
  album_override="$(echo "$overrides" | jq -r ".album // \"$ALBUM\"")"

  echo "Overrides: $overrides" >&2
  echo "Artist override: $artist_override" >&2
  echo "Album override: $album_override" >&2

  synced_lyrics="$(
    curl -X GET -sG \
      -H "Lrclib-Client: rmpc-$VERSION" \
      --data-urlencode "artist_name=$artist_override" \
      --data-urlencode "album_name=$album_override" \
      --data-urlencode "track_name=$TITLE" \
      "https://lrclib.net/api/get" | jq -r '.syncedLyrics'
  )"

  if [ -z "$synced_lyrics" ]; then
      [ -n "$PID" ] && rmpc remote --pid "$PID" status "Failed to download lyrics for $ARTIST - $TITLE" --level error
      exit 0
  fi

  if [ "$synced_lyrics" = "null" ]; then
      # no need to log this, it just means no lyrics were found
      # rmpc remote --pid "$PID" status "Lyrics for $ARTIST - $TITLE not found" --level warn
      exit 0
  fi

  # populate the lyrics file
  {
    echo "[ar:$ARTIST]"
    echo "[al:$ALBUM]"
    echo "[ti:$TITLE]"
    echo "$synced_lyrics" | sed -E '/^\[(ar|al|ti):/d'
  } > "$LRC_FILE"

  [ -n "$PID" ] && rmpc remote --pid "$PID" indexlrc --path "$LRC_FILE"
fi

# example non-rmpc usage:
#(
#  export      ARTIST='King Gizzard & the Lizard Wizard' && \
#  export       ALBUM='Nonagon Infinity' && \
#  export        DATE='2016' && \
#  export TRACKNUMBER='3' && \
#  export       TITLE='Gamma Knife' && \
#  export    LRC_FILE="${HOME}/.cache/rmpc/lyrics/${ARTIST}/${DATE} ${ALBUM}/$(printf '%02d' "$TRACKNUMBER") ${TITLE}.lrc" && \
#  export     HAS_LRC="$([ ! -s "$LRC_FILE" ] && echo "false")" && \
#  export     VERSION='0.9.0' && \
#  ~/.config/rmpc/on-song-change.d/download-lyrics.sh && \
#  cat "$LRC_FILE"
#)
