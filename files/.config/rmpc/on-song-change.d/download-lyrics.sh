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
