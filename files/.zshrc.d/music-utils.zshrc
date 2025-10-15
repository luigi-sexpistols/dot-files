current-artist () {
    mpc status -f "%artist%" | head -n 1
}

current-album-artist () {
    mpc status -f "%albumartist%" | head -n 1
}

current-album () {
    mpc status -f "%album%" | head -n 1
}

current-title () {
    mpc status -f "%title%" | head -n 1
}

dump-music-metadata () {
    cd ~/Music

    local track file artist album year genres

    get-tag () {
      local tag="$1"
      local file="$2"

      metaflac --show-tag="$tag" "$file" | sed -E "s/^${tag}=//"
    }

    for artist_dir in *; do
      for album_dir in "$artist_dir"/*; do
        track="$(find "$album_dir" -type f -name '*.flac' -print -quit | sed "s|^$album_dir||")"
        file="$(realpath "$album_dir"/"$track")"

        [ -z "$track" ] && echo "Failed to find track in ${album_dir}" >&2 && continue
        [ ! -f "$file" ] && echo "File '$file' does not exist!" >&2 && continue

        artist="$(get-tag ALBUMARTIST "$file")"
        album="$(get-tag ALBUM "$file")"
        year="$(get-tag DATE "$file")"
        genres="$(get-tag GENRE "$file" | tr '\n' ';' | sed 's/;*\s*$//')"

        echo "$artist|$album|$year|$genres"
      done
    done
}

wal-backend () {
    local status_file="$HOME"/.cache/rmpc/current_album
    local prefs_file="$HOME"/.config/rmpc/on-song-change.json

    p-regenerate () {
        local artist album
        local backend="$1"

        artist="$(current-album-artist)"
        album="$(current-album)"

        if [ -z "$artist" ] || [ -z "$album" ]; then
            echo "No song is currently playing, aborting regeneration."
            return 0
        fi

        export artist
        export album
        export backend

        (
            # in its own subshell to avoid polluting the environment
            export PID="$(pidof -s rmpc)"
            export ALBUMARTIST="$artist"
            export ALBUM="$album"
            export WAL_BACKEND="$backend"

           p-reset-status
            ~/.config/rmpc/on-song-change.d/update-color-scheme.sh
        )
    }

    p-save () {
        local temp_file=/tmp/rmpc-prefs.json
        local media_info artist album
        local backend="$1"

        artist="$(current-artist)"
        album="$(current-album)"

        if [ -z "$artist" ] || [ -z "$album" ]; then
            echo "No song is currently playing, aborting regeneration." >&2
            return 0
        fi

        if [ -n "$backend" ]; then
            echo "Backend specified: '$backend'." >&2
        else
            backend="$(cat "$status_file" | grep -Eo '^BACKEND=.+$' | cut -d '=' -f 2-)"
            echo "Backend from status: '$backend'." >&2
        fi

        cat "$prefs_file" \
        | jq \
            --arg artist "$(slugify "$artist")" \
            --arg album "$(slugify "$album")" \
            --arg backend "$backend" \
            '.update_color_scheme.backend.override[$artist][$album] += [$backend] | .update_color_scheme.backend.override[$artist][$album] |= unique' \
        | jq -MRsr 'gsub("\n            +";"")|gsub("\n          ]";"]")' \
        > "$temp_file"

        mv "$temp_file" "$prefs_file"
        echo "Saved backend '$backend' for $artist - $album"
    }

    p-current () {
        cat "$status_file"
    }

    p-reset-status () {
        echo '' > "$status_file"
    }

    entrypoint () {
        local command="$1"

        case "$command" in
            'regenerate') p-regenerate "${@:2}" ;;
            'save') p-save "${@:2}" ;;
            'current') p-current ;;
            'status') p-current ;;
            'reset-status') p-reset-status ;;
            *)
                echo "Usage: wal-backend {save}"
                return 1
                ;;
        esac
    }

    entrypoint "$@"
}

lyric-search () {
    entrypoint () {
        local now_playing="false"
        local exact="true"
        local artist title
        local results results_table found

        eval set -- "$(getopt --long='now-playing,q-query,artist:,title:' --name "$0" -- '' "$@")"

        while true; do
            case "$1" in
                --now-playing) now_playing="true"; shift 2 ;;
                --q-query) exact="false"; shift 2 ;;
                --artist) artist="$2"; shift 2 ;;
                --title) title="$2"; shift 2 ;;
                --) shift; break ;;
                *) break ;;
            esac
        done

        if [ "$now_playing" = "true" ]; then
            [ -n "$artist" ] && echo "Do not provide --artist when --now-playing is set." >&2 && return 1
            [ -n "$title" ] && echo "Do not provide --title when --now-playing is set." >&2 && return 1

            artist="$(current-artist)"
            title="$(current-title)"

            echo "Searching for '${artist}' - '${title}' from current playing song..."
        else
            [ -z "$artist" ] && echo "You must provide --artist when not using --now-playing." >&2 && return 1
            [ -z "$title" ] && echo "You must provide --title when not using --now-playing." >&2 && return 1
        fi

        if [ "$exact" = "false" ]; then
            results="$(
                curl -X GET -sG \
                    -H "Lrclib-Client: rmpc-$(rmpc version | cut -d' ' -f2)" \
                    --data-urlencode "q=${artist} ${title}" \
                    'https://lrclib.net/api/search'
            )"
        else
            results="$(
                curl -X GET -sG \
                    -H "Lrclib-Client: rmpc-$(rmpc version | cut -d' ' -f2)" \
                    --data-urlencode "artist_name=${artist}" \
                    --data-urlencode "track_name=${title}" \
                    'https://lrclib.net/api/search'
            )"
        fi

        # clean out control characters that break jq and generally clean up the list
        results="$(
            echo "$results" \
            | tr -d '\000-\037' \
            | jq '.[] | select(.syncedLyrics != "" and .syncedLyrics != null)' \
            | jq -s '.'
        )"

#         echo "$results"

        found="$(echo "$results" | jq length)"

        if [ "$found" -gt 0 ]; then
            {
                echo 'ID|Artist|Album|Title'
                echo '--|------|-----|-----'
                echo "$results" | jq -c '.[] | select(.syncedLyrics) | {id,artistName,albumName,trackName}' | while read -r item; do
                  echo "$item" | jq -r 'join("|")'
                done
            } | column -t -s'|'
        else
            echo 'No results found with `.syncedLyrics`...' >&2
        fi
    }

    entrypoint "$@"
}

dac-refresh () {
    echo -n "Restarting PulseAudio... "
    pulseaudio --kill
    pulseaudio --start
    echo " done"

    echo -n "Restarting PipeWire..."
    systemctl --user restart pipewire.service
    echo " done"

    echo -n "Toggling music..."
    mpc pause --wait > /dev/null 2>&1
    mpc play > /dev/null 2>&1
    echo " done"

    echo
    echo "Enjoy the tunes! :D"
}
