#!/bin/env bash

get-override-pref () {
  local root_pref='.lyrics.override'
  local value_pref="$1"

  if [[ "$value_pref" =~ ^\\. ]]; then
    echo "Invalid preference path '$value_pref'; must start with a dot." >&2
    exit $LINENO
  fi

  local json_path="${root_pref}${value_pref}"

#  echo "Contents of '$prefs_file':" >&2
#  cat "$prefs_file" >&2

  echo "Retrieving preference at '${json_path}' from '$prefs_file'." >&2
  cat "$prefs_file" | jq -c "$json_path"
}

echo "HAS_LRC: $HAS_LRC" >&2
echo "LRC_FILE: $LRC_FILE" >&2

config_dir="$HOME"/.config/rmpc
prefs_file="$config_dir"/on-song-change.json

type slugify &>/dev/null || source "$HOME"/.zshrc.d/01-dependency-functions.zshrc

if [ "$HAS_LRC" = "false" ]; then
  mkdir -p "$(dirname "$LRC_FILE")"

  prefs_artist="$(slugify "$ALBUMARTIST")"
  prefs_album="$(slugify "$ALBUM")"

  overrides="$(get-override-pref ".[\"$prefs_artist\"][\"$prefs_album\"]")"

  if [ "$overrides" = "null" ]; then
    echo "No overrides found for $ALBUMARTIST - $ALBUM" >&2
    overrides="{}"
  fi

  id_override="$(echo "$overrides" | jq -r ".[\"$TRACK\"].id // empty")"
  artist_override="$(echo "$overrides" | jq -r ".[\"$TRACK\"].artist // .artist // \"$ALBUMARTIST\"")"
  album_override="$(echo "$overrides" | jq -r ".[\"$TRACK\"].album // .album // \"$ALBUM\"")"
  title_override="$(echo "$overrides" | jq -r ".[\"$TRACK\"].title // \"$TITLE\"")"

  echo "Track number: $TRACK" >&2
  echo "Overrides: $overrides" >&2
  echo "Search values:" >&2

#  user_agent_header="User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"
  user_agent_header="Lrclib-Client: rmpc/${VERSION}"

  if [ -n "$id_override" ]; then
    echo "ID: $id_override" >&2

    http_response="$(curl -X GET -sG -H "$user_agent_header" "https://lrclib.net/api/get/${id_override}")"

#    echo "Response from lrclib.net/api/get/${id_override}:" >&2
#    echo "$http_response" >&2

    synced_lyrics="$(echo "$http_response" | jq -r '.syncedLyrics')"
  else
    echo "Artist: $artist_override" >&2
    echo "Album: $album_override" >&2
    echo "Title: $title_override" >&2

    http_response="$(
      curl -X GET -sG \
        -H "$user_agent_header" \
        --data-urlencode "artist_name=$artist_override" \
        --data-urlencode "album_name=$album_override" \
        --data-urlencode "track_name=${title_override}" \
        "https://lrclib.net/api/get"
    )"

#    echo "Response from lrclib.net/api/get:" >&2
#    echo "$http_response" >&2

    synced_lyrics="$(echo "$http_response" | jq -r '.syncedLyrics')"
  fi

  if [ -z "$synced_lyrics" ]; then
      [ -n "$PID" ] && rmpc remote --pid "$PID" status "Failed to download lyrics for $ALBUMARTIST - $TITLE" --level error
      exit 0
  fi

  if [ "$synced_lyrics" = "null" ]; then
      # no need to log this, it just means no lyrics were found
      # rmpc remote --pid "$PID" status "Lyrics for $ALBUMARTIST - $TITLE not found" --level warn
      exit 0
  fi

  # populate the lyrics file
  {
    echo "[ar:$ALBUMARTIST]"
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
