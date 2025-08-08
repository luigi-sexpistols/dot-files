wal-regenerate () {
    local current_album_file="$HOME"/.cache/rmpc/current_album

    # get the current track metadata
    # remove the current_album file
    # call update-color-scheme.sh
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

    p-save () {
        local temp_file=/tmp/rmpc-prefs.json
        local artist album backend

        artist="$(cat "$status_file" | grep -Eo '^ARTIST=.+$' | cut -d '=' -f 2-)"
        album="$(cat "$status_file" | grep -Eo '^ALBUM=.+$' | cut -d '=' -f 2-)"
        backend="$(cat "$status_file" | grep -Eo '^BACKEND=.+$' | cut -d '=' -f 2-)"
        echo "Saving pending backend '$backend' for $artist - $album"

        cat "$prefs_file" \
        | jq \
            --arg artist "$(p-slugify "$artist")" \
            --arg album "$(p-slugify "$album")" \
            --arg backend "$backend" \
            '.update_color_scheme.backend.override_pending[$artist][$album] += [$backend] | .update_color_scheme.backend.override_pending[$artist][$album] |= unique' \
            > "$temp_file" \
        && mv "$temp_file" "$prefs_file"
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
