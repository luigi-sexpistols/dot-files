#!/usr/bin/env sh

home_dir='/home/ashley'
config_dir="$home_dir"/.config/rmpc
art_dir="$home_dir"/.cache/rmpc/art

default_art_file="$home_dir"/Pictures/full.png

slugify () {
    echo "$1" | \
        sed -E 's/ & / and /g' | \
        sed -E 's/[^a-zA-Z0-9]/_/g' | \
        sed -E 's/_{2,}/_/g' | \
        sed -E 's/^_//g' | \
        tr '[:upper:]' '[:lower:]'
}

art_file="$art_dir/$(slugify "$ARTIST")/$(slugify "$ALBUM")"

if [ ! -f "$art_file" ]; then
    mkdir -p "$(dirname "$art_file")"

    if ! rmpc albumart --output "$art_file"; then
        art_file="$default_art_file"
    fi
fi

# for some reason the `wal` command is causing a frequent but intermittent issue in rmpc.
# leave this enabled for long and you'll see it
wal -nste -i "${art_file}" --backend=colorz

# reload theme
theme=$(cat "$config_dir"/config.ron | grep 'theme' | grep -Eo '"[^"]+"' | grep -Eo '[^"]+')
rmpc remote set theme "${config_dir}/themes/${theme}.ron" || rmpc remote --pid "$PID" status "Failed to set theme '${theme}'." --level error
