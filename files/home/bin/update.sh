#!/usr/bin/env bash

set -e

if [ "$(whoami)" != "root" ]; then
  echo 'Must be run as root, elevating with sudo...'
  sudo bash "$0" "$@"
  exit $?
fi

# refresh mirrors
pacman-mirrors -f

# update system
pamac upgrade -a --no-confirm --aur --devel

# todo - support "list of packages to be ignored"
