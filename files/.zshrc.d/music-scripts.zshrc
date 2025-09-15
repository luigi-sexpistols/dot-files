current-artist () {
    mpc status -f "%artist%" | head -n 1
}

current-album-artist () {
    mpc status -f "%albumartist%" | head -n 1
}

current-album () {
    mpc status -f "%album%" | head -n 1
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
            echo "No song is currently playing, aborting regeneration."
            return 0
        fi

        if [ -n "$backend" ]; then
            echo "Backend specified: '$backend'."
        else
            backend="$(cat "$status_file" | grep -Eo '^BACKEND=.+$' | cut -d '=' -f 2-)"
            echo "Backend from status: '$backend'."
        fi

        echo "Saving pending backend '$backend' for $artist - $album"

        cat "$prefs_file" \
        | jq \
            --arg artist "$(slugify "$artist")" \
            --arg album "$(slugify "$album")" \
            --arg backend "$backend" \
            '.update_color_scheme.backend.override_pending[$artist][$album] += [$backend] | .update_color_scheme.backend.override_pending[$artist][$album] |= unique' \
        | jq -MRsr 'gsub("\n            +";"")|gsub("\n          ]";"]")' \
        > "$temp_file"

        mv "$temp_file" "$prefs_file"
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
