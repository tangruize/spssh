#!/bin/bash

# zstd is better than gzip, you should install it on both host and clients before use
#COMPRESS_PROGRAM=zstd
COMPRESS_PROGRAM=${COMPRESS_PROGRAM:-gzip}
#FIND_ARGS='-maxdepth 1 -name *.sh'
FIND_ARGS=$FIND_ARGS
#START_NO_ASK=true
START_NO_ASK=${START_NO_ASK:-false}
#EXIT_NO_ASK=true
EXIT_NO_ASK=${EXIT_NO_ASK:-false}

if test "$#" -eq 0; then
    echo 1>&2 "Usage: $0 FILE/DIR [REMOTE_DIR] | `dirname $0`/spssh.sh user1@server1 [user2@server2 ...]"
    echo 1>&2 "       $0 FILE/DIR [REMOTE_DIR]  # without piping in tmux session"
    test -t 1 || (read -N 1 -sp "Press any key to exit: " && echo " exit")
    exit
fi

if test -t 1 -a -n "$TMPDIR"; then
    env ALREADY_RUNNING=true "$0" $@ >> "$TMPDIR/host"
    exit
fi

FILE=`basename "$1"`
SRCDIR=`dirname "$1"`
DSTDIR=${2:-.}

if test -z "$ALREADY_RUNNING"; then
    if test -t 0 -a "$START_NO_ASK" != "true"; then
        sleep 0.1
        read -N 1 -p "Press ENTER to start or any key to cancel: "
        test "$(echo "$REPLY")" != "$(echo)" && echo " exit" && exit
    else
        sleep 1
    fi
fi

echo -e " stty -echo; PSBAK=\$PS1; unset PS1; sleep 0.5"
sleep 0.5
echo " echo Receiving '$FILE ...'; mkdir -p '$DSTDIR'; bash -c \"stty -echo -icanon intr undef; stdbuf -i 4K sed '/^ /q' | dd bs=64K iflag=fullblock status=progress | base64 -d 2> /dev/null | tar xv -I $COMPRESS_PROGRAM -C '$DSTDIR' 2> /dev/null || (echo 1>&2 -e '\nInterrupted by user'; sleep 3; exit 1)\" || exit 1"
(cd "$SRCDIR"; find "$FILE" $FIND_ARGS -print0 | tar cv -I $COMPRESS_PROGRAM --null -T - | base64 -w 4095 | dd bs=4K status=progress; awk 'BEGIN{ for (b=0; b<2; b++) { for (c=0; c<4095; c++) { printf " " } printf "\n" } }' | dd bs=4K 2>/dev/null; echo " stty echo icanon intr ^C; PS1=\$PSBAK; unset PSBAK")

if test -z "$ALREADY_RUNNING"; then
    if test -t 0; then
        if test "$EXIT_NO_ASK" != "true"; then
            read -N 1 -p "Exit host REPL and all clients? [y/N] "
        else
            REPLY=y
        fi
    else
        REPLY=N
    fi
    REPLY=${REPLY,,}
    if test "$REPLY" != "y"; then
        $(dirname "$0")/spssh.sh repl pipe
        EXIT_STATUS=$?
    fi
    echo 1>&2
    if test "$REPLY" = "y" -o "$EXIT_STATUS" != 0; then
        test -t 0 && echo -e "\n exit"
    fi
fi
