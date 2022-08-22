#!/bin/bash

if test "$#" -eq 0; then
    echo Usage: $0 user1@server1 [user2@server2 ...]
    exit 1
fi

terms=(x-terminal-emulator gnome-terminal mate-terminal xfce4-terminal konsole)
for t in ${terms[*]}; do
    if [ $(command -v $t) ]; then
        XTERM=$t
        break
    fi
done

if [ -z "$XTERM" ]; then
    echo Error: Cannot find a terminal emulator
    exit 1
fi

export TMPDIR=`mktemp -d -p /tmp`
TMPFILE=`mktemp`
RMTMPDIR="rmdir --ignore-fail-on-non-empty $TMPDIR 2> /dev/null"
KILLCAT="pkill -g 0 -x cat"
KILLEXIT="find $TMPDIR -type p -exec false {} + && ($RMTMPDIR; kill -INT -- -$$)"
KILLPIPE="find $TMPDIR -type p -exec lsof -t {} + | xargs --no-run-if-empty kill"

trap "echo Quitting ...; trap '' INT TERM" INT TERM
trap "rm -f $TMPFILE; $RMTMPDIR" EXIT

while test "$#" -gt 0; do
    TMPFIFO=`mktemp -u`
    mkfifo $TMPFIFO
    CMD="bash -c 'stty -echo -echoctl raw; (tail -f $TMPFILE >> $TMPFIFO; $KILLCAT) & (setsid ssh -tt $1 < $TMPFIFO; $KILLCAT) & (cat >> $TMPFIFO; rm -f $TMPFIFO; $KILLEXIT)'"
    shift
    if test "$XTERM" = "gnome-terminal"; then
        eval $XTERM -- $CMD &
    else
        $XTERM -e "$CMD" 2> /dev/null &
    fi
done

if test -t 0; then
    echo "Run commands on all servers, Ctrl + D to exit:"
    stty intr undef
    bash -c "HISTFILE=$TMPFILE; set -o history; while read -ep '$ '; do echo \"\$REPLY\" >> $TMPFILE; history -n; done; set +o history"
    eval $KILLPIPE
    stty intr ^C
else
    cat >> $TMPFILE
fi
