#!/bin/bash

if test "$#" -eq 0; then
    echo Usage: $0 user1@server1 [user2@server2 ...]
    exit 1
fi

XTERM=$(realpath `command -v x-terminal-emulator`)
if test -z "$XTERM"; then
    echo Error: Cannot find x-terminal-emulator
    exit 1
fi
#XTERM="/usr/bin/gnome-terminal"

export TMPDIR=`mktemp -d -p /tmp`
TMPFILE=`mktemp`
bash -c 'kill -STOP $$' &
EXITPID=$!

while test "$#" -gt 0; do
    TMPFIFO=`mktemp -u`
    mkfifo $TMPFIFO
    CMD="bash -c 'tail -F $TMPFILE --pid $EXITPID >> $TMPFIFO && pkill -g 0 cat & stty -echo -echoctl raw; ssh -tt $1 < $TMPFIFO & cat >> $TMPFIFO'"
    shift
    if test "$XTERM" = "/usr/bin/gnome-terminal"; then
        eval $XTERM -- $CMD &
    else
        $XTERM -e "$CMD" &
    fi
done

trap 'echo Quitting ...; pkill -g 0 cat; trap "" 2 15' 2 15
echo Run commands on all servers, Ctrl + D to exit:
stty intr ^D
cat >> $TMPFILE
kill -CONT $EXITPID
sleep 1
rm -rf $TMPDIR
stty intr ^C
