get-lyrics () {
  export      ARTIST="$1" && \
  export       ALBUM="$2" && \
  export        DATE="$3" && \
  export TRACKNUMBER="$4" && \
  export       TITLE="$5" && \
  export    LRC_FILE="${HOME}/.cache/rmpc/lyrics/${ARTIST}/${DATE} ${ALBUM}/$(printf '%02d' "$TRACKNUMBER") ${TITLE}.lrc" && \
  export     HAS_LRC="$([ ! -s "$LRC_FILE" ] && echo "false")" && \
  export     VERSION='0.9.0' && \
  ~/.config/rmpc/on-song-change.d/download-lyrics.sh
}

# example:
# get-lyrics 'King Gizzard & the Lizard Wizard' 'Nonagon Infinity' 2016 3 'Gamma Knife'

# todo - this sucks, make it not suck
