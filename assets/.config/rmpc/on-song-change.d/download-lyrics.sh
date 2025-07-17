#!/bin/env sh

LRCLIB_INSTANCE="https://lrclib.net"

if [ "$HAS_LRC" = "false" ]; then
    mkdir -p "$(dirname "$LRC_FILE")"

    LYRICS="$(
        curl -X GET -sG \
            -H "Lrclib-Client: rmpc-$VERSION" \
            --data-urlencode "artist_name=$ARTIST" \
            --data-urlencode "album_name=$ALBUM" \
            --data-urlencode "track_name=$TITLE" \
            "$LRCLIB_INSTANCE/api/get" | jq -r '.syncedLyrics'
    )"

    if [ -z "$LYRICS" ]; then
        rmpc remote --pid "$PID" status "Failed to download lyrics for $ARTIST - $TITLE" --level error
        exit
    fi

    if [ "$LYRICS" = "null" ]; then
        # no need to log this, it just means no lyrics were found
        # rmpc remote --pid "$PID" status "Lyrics for $ARTIST - $TITLE not found" --level warn
        exit
    fi

    # Create and populate the lyrics file
    [ ! -f "$LRC_FILE" ] && touch "$LRC_FILE"
    {
      echo "[ar:$ARTIST]"
      echo "[al:$ALBUM]"
      echo "[ti:$TITLE]"
    } >>"$LRC_FILE"
    echo "$LYRICS" | sed -E '/^\[(ar|al|ti):/d' >>"$LRC_FILE"

    rmpc remote --pid "$PID" indexlrc --path "$LRC_FILE"
fi
