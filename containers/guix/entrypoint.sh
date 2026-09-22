#!/bin/sh
set -eu

guix-daemon --build-users-group=guixbuild --disable-chroot &

i=0
until [ -S /var/guix/daemon-socket/socket ] || [ "$i" -ge 30 ]; do
  sleep 1
  i=$((i + 1))
done

for key in ci.guix.gnu.org bordeaux.guix.gnu.org; do
  guix archive --authorize < "/root/.config/guix/current/share/guix/$key.pub"
done

exec "$@"
