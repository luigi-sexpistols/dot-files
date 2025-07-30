get-media-info () {
  get-spotify-info () {
    media_info=$(
      dbus-send \
        --print-reply \
        --dest=org.mpris.MediaPlayer2.spotify \
        /org/mpris/MediaPlayer2 \
        org.freedesktop.DBus.Properties.Get \
        string:org.mpris.MediaPlayer2.Player \
        string:Metadata
    )

    artist="$(echo "$media_info" | sed -n '/:artist"/{n;n;p}' | cut -d '"' -f 2)"
    album="$(echo "$media_info" | sed -n '/:album"/{n;P}' | cut -d '"' -f 2)"
    title="$(echo "$media_info" | sed -n '/:title"/{n;p}' | cut -d '"' -f 2)"
    track_number="$(echo "$media_info" | sed -n '/:trackNumber"/{n;p}' | sed -E 's/^.+int32 //')"

    echo "$artist|$album|$title|$track_number"
  }

  local artist album title date track_number

  IFS='|' read -r artist album title track_number <<< "$(get-spotify-info)"

  echo "  SOURCE: Spotify"
  echo "  ARTIST: $artist"
  echo "   ALBUM: $album"
  echo "   TITLE: $title"
  echo "TRACK_NO: $track_number"
}
