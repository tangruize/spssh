#!/bin/bash

if test "$#" -eq 0; then
    echo 1>&2 "Usage: $0 FILE/DIR [REMOTE_DIR] | `dirname $0`/spssh.sh user1@server1 [user2@server2 ...]"
    test -t 1 || (read -N 1 -sp "Press any key to exit: " && echo " exit")
    exit
fi

FILE=`basename "$1"`
SRCDIR=`dirname "$1"`
DSTDIR=${2:-.}

read -N 1 -p "Press ENTER to start or any key to cancel: "
test "$(echo "$REPLY")" != "$(echo)" && echo " exit" && exit

echo " stty -echo"
sleep 0.5
echo " echo; mkdir -p '$DSTDIR'; bash -c \"stty -echo -icanon; trap 'stty echo icanon' EXIT; awk '/^@$/{exit} 1' | dd bs=64K iflag=fullblock status=progress | base64 -d 2> /dev/null | tar xz -C '$DSTDIR' 2> /dev/null || (echo 1>&2 -e '\nInterrupted by user'; sleep 3; exit 1)\" || exit 1"
tar cz -C "$SRCDIR" "$FILE" | base64 -w 4095 | dd bs=4K status=progress
echo @

read -N 1 -p "Exit? [y/N] "
if test "$REPLY" != "y"; then
    if test -t 0; then
        stty intr undef
        TMPFILE=`mktemp`
        bash -c "HISTFILE=$TMPFILE; set -o history; while read -ep '$ '; do echo \"\$REPLY\" | tee -a $TMPFILE; history -n; done; set +o history"
        rm -f $TMPFILE
        stty intr ^C
    else
        cat
    fi
fi
echo 1>&2
echo " exit"
