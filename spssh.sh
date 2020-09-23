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
KILLCAT="pkill -g 0 -x cat"
KILLEXIT="find $TMPDIR -type p -exec false {} + && kill -INT -- -$$"
KILLPIPE="find $TMPDIR -type p -exec lsof -t {} + | xargs --no-run-if-empty kill"

while test "$#" -gt 0; do
    TMPFIFO=`mktemp -u`
    mkfifo $TMPFIFO
    CMD="bash -c 'stty -echo -echoctl raw; (tail -f $TMPFILE >> $TMPFIFO; $KILLCAT) & (setsid ssh -tt $1 < $TMPFIFO; $KILLCAT) & (cat >> $TMPFIFO; rm -f $TMPFIFO; $KILLEXIT)'"
    shift
    if test "$XTERM" = "/usr/bin/gnome-terminal"; then
        eval $XTERM -- $CMD &
    else
        $XTERM -e "$CMD" 2> /dev/null &
    fi
done

trap "echo Quitting ...; $KILLPIPE; $KILLCAT; trap '' 2 15" 2 15
echo Run commands on all servers, Ctrl + D to exit:
stty intr ^D
cat >> $TMPFILE
eval $KILLPIPE
sleep 1
rm -rf $TMPDIR
stty intr ^C
