#!/bin/sh
# Lock the session, and return only once it is locked.
#
# The lock screen is the shell's own (surfaces/Lock.qml). If the shell is not
# running it is started first, so a crashed bar never means an unlocked
# laptop. Waiting matters for swayidle's before-sleep hook: it holds the
# suspend until this exits, so the machine never sleeps — or wakes — with
# the desktop showing.

locked() { [ "$(qs ipc call lock isLocked 2>/dev/null)" = "true" ]; }

locked && exit 0

if ! qs ipc call lock lock >/dev/null 2>&1; then
    systemctl --user restart quickshell.service
    i=0
    until qs ipc call lock lock >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -ge 50 ] && { echo "lock.sh: the shell did not start" >&2; exit 1; }
        sleep 0.1
    done
fi

i=0
until locked; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && { echo "lock.sh: the lock did not take" >&2; exit 1; }
    sleep 0.1
done
