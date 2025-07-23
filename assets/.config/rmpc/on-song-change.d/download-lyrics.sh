#!/bin/env bash

lrclib_api_url="https://lrclib.net"

if [ "$HAS_LRC" = "false" ]; then
  mkdir -p "$(dirname "$LRC_FILE")"

  synced_lyrics="$(
    curl -X GET -sG \
      -H "Lrclib-Client: rmpc-$VERSION" \
      --data-urlencode "artist_name=$ARTIST" \
      --data-urlencode "album_name=$ALBUM" \
      --data-urlencode "track_name=$TITLE" \
      "$lrclib_api_url/api/get" | jq -r '.syncedLyrics'
  )"

  if [ -z "$synced_lyrics" ]; then
      [ -z "$PID" ] && rmpc remote --pid "$PID" status "Failed to download lyrics for $ARTIST - $TITLE" --level error
      exit 0
  fi

  if [ "$synced_lyrics" = "null" ]; then
      # no need to log this, it just means no lyrics were found
      # rmpc remote --pid "$PID" status "Lyrics for $ARTIST - $TITLE not found" --level warn
      exit 0
  fi

  # Create and populate the lyrics file
  [ ! -f "$LRC_FILE" ] && touch "$LRC_FILE"
  [ ! -s "$LRC_FILE" ] && echo '' > "$LRC_FILE"

  {
    echo "[ar:$ARTIST]"
    echo "[al:$ALBUM]"
    echo "[ti:$TITLE]"
  } >>"$LRC_FILE"

  echo "$synced_lyrics" | sed -E '/^\[(ar|al|ti):/d' >> "$LRC_FILE"

  [ -z "$PID" ] && rmpc remote --pid "$PID" indexlrc --path "$LRC_FILE"
fi

# exit to avoid running the example
exit 0

# example non-rmpc usage:
(
  export      ARTIST='Leprous' && \
  export       ALBUM='Aphelion' && \
  export        DATE='2021' && \
  export TRACKNUMBER='1' && \
  export       TITLE='Running Low' && \
  export    LRC_FILE="~/.cache/rmpc/lyrics/${ARTIST}/${DATE} ${ALBUM}/$(printf '%02d' "$TRACKNUMBER") ${TITLE}.lrc" && \
  export     HAS_LRC="$([ ! -s "$LRC_FILE" ])" && \
  export     VERSION='0.9.0' && \
  ~/.config/rmpc/on-song-change.d/download-lyrics.sh && \
  cat "$LRC_FILE"
)
