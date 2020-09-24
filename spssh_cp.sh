#!/bin/bash

if test "$#" -eq 0; then
    echo 1>&2 "Usage: $0 FILE/DIR [REMOTE_DIR] | `dirname $0`/spssh.sh user1@server1 [user2@server2 ...]"
    test -t 1 || (read -N 1 -p "Press any key to exit: " && echo " exit")
    exit
fi

FILE=`basename "$1"`
SRCDIR=`dirname "$1"`
DSTDIR=${2:-.}
TARBASE64="`mktemp -u`.$FILE.tar.gz.base64"
tar cz -C "$SRCDIR" "$FILE" | base64 > "$TARBASE64" &
trap "rm -f '$TARBASE64'" EXIT

read -N 1 -p "Press ENTER to start or any key to cancel: "
test "$(echo "$REPLY")" != "$(echo)" && echo " exit" && exit
wait 2> /dev/null
NBYTES=`du -b "$TARBASE64" | cut -f1`

echo " bash -c 'stty -echo; trap \"stty echo\" EXIT; mkdir -p \"$DSTDIR\"; time head -c $NBYTES | if command -v pv >/dev/null; then pv -IWfateps $NBYTES; else cat; fi | base64 -id | tar xz -C \"$DSTDIR\" || (echo DO NOT TYPE ANY KEY WHILE PROGRESSING; sleep 3; exit 1)' || exit 1"
sleep 0.5
cat "$TARBASE64"

read -N 1 -p "Exit? [y/N] "
if test "$REPLY" != "y"; then
    if test -t 0; then
        stty intr undef
        while read -ep "$ "; do echo "$REPLY"; done
        stty intr ^C
    else
        cat
    fi
fi
echo " exit"
