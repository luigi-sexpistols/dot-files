current-artist () {
    mpc status -f "%artist%" | head -n 1
}

current-album () {
    mpc status -f "%album%" | head -n 1
}

wal-backend () {
    local status_file="$HOME"/.cache/rmpc/current_album
    local prefs_file="$HOME"/.config/rmpc/on-song-change.json

    p-slugify () {
      echo "$1" \
      | sed -E 's/ & / and /g' \
      | sed -E 's/[^a-zA-Z0-9]/_/g' \
      | sed -E 's/_{2,}/_/g' \
      | sed -E 's/^_//g' \
      | sed -E 's/_$//g' \
      | tr '[:upper:]' '[:lower:]'
    }

    p-regenerate () {
        local artist album backend

        artist="$(current-artist)"
        album="$(current-album)"

        if [ -z "$artist" ] || [ -z "$album" ]; then
            echo "No song is currently playing, aborting regeneration."
            return 0
        fi

        (
            # in its own subshell to avoid polluting the environment
            export PID="$(pidof -s rmpc)"
            export ARTIST="$artist"
            export ALBUM="$album"

           p-reset-status
            ~/.config/rmpc/on-song-change.d/update-color-scheme.sh
        )
    }

    p-save () {
        local temp_file=/tmp/rmpc-prefs.json
        local media_info artist album backend

        artist="$(current-artist)"
        album="$(current-album)"

        if [ -z "$artist" ] || [ -z "$album" ]; then
            echo "No song is currently playing, aborting regeneration."
            return 0
        fi

        backend="$(cat "$status_file" | grep -Eo '^BACKEND=.+$' | cut -d '=' -f 2-)"
        echo "Saving pending backend '$backend' for $artist - $album"

        cat "$prefs_file" \
        | jq \
            --arg artist "$(p-slugify "$artist")" \
            --arg album "$(p-slugify "$album")" \
            --arg backend "$backend" \
            '.update_color_scheme.backend.override_pending[$artist][$album] += [$backend] | .update_color_scheme.backend.override_pending[$artist][$album] |= unique' \
        | jq -MRsr 'gsub("\n            +";"")|gsub("\n          ]";"]")' \ # number of spaced sets the max depth of "pretty-print" output
        > "$temp_file"

        mv "$temp_file" "$prefs_file"
    }

    p-current () {
        cat "$status_file" | grep -Eo '^BACKEND=.+$' | cut -d '=' -f 2-
    }

    p-reset-status () {
        echo '' > "$status_file"
    }

    entrypoint () {
        local command="$1"

        case "$command" in
            'regenerate') p-regenerate ;;
            'save') p-save ;;
            'current') p-current ;;
            'reset-status') p-reset-status ;;
            *)
                echo "Usage: wal-backend {save}"
                return 1
                ;;
        esac
    }

    entrypoint "$@"
}
