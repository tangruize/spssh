#!/bin/bash

#FIND_ARGS="-maxdepth 1 -name \*.sh"
FIND_ARGS=$FIND_ARGS

# Compress before base64 (the transmission data has 33% overhead due to base64):
# No need to compress for fast connections and low compression ratio files
# zstd is better than gzip, but it should be install manually
#COMPRESS_PROGRAM=zstd
#COMPRESS_PROGRAM=gzip
COMPRESS_PROGRAM=${COMPRESS_PROGRAM:-none}

# Safe mode is extremely slow, it solves the stdio buffering problem:
# e.g. echo -e 'a\nb\nc' | (sed    '1q'; sed    '1q'; sed    '1q')  ->  a
#      echo -e 'a\nb\nc' | (sed -u '1q'; sed -u '1q'; sed -u '1q')  ->  a b c
# if safe mode is disabled, it uses big sentinel paddings to feed stdio buffer (in most cases, it is safe enough)
#SAFE_MODE=true
SAFE_MODE=${SAFE_MODE:-false}

#BEGIN_NO_ASK=true
BEGIN_NO_ASK=${BEGIN_NO_ASK:-false}

#EXIT_NO_ASK=true
EXIT_NO_ASK=${EXIT_NO_ASK:-false}

# Fake tty is used to run "script" program after receiving files.
# It is combined with spssh.sh --no-tty option, which makes file transferring super fast.
#FAKE_TTY=true
FAKE_TTY=${FAKE_TTY:-false}

if test -t 1 -a -n "$TMPDIR"; then
    env ALREADY_RUNNING=true "$0" $@ >> "$TMPDIR/host"
    exit
fi

function usage() {
    echo 1>&2 "Usage: spssh_cp.sh [--find-args '-maxdepth 1 -name \*.sh ..'] [--safe-mode]"
    echo 1>&2 "                   [--compress-program none/gzip/zstd/..] [--fake-tty]"
    echo 1>&2 "                   [--begin-no-ask] [--exit-no-ask] FILE/DIR [REMOTE_DIR]"
    echo 1>&2 "        | spssh.sh [options ..] user1@server1 [user2@server2 ..]"
    echo 1>&2 "Usage: spssh_cp.sh [options ..] FILE/DIR [REMOTE_DIR]  # in tmux session"
    echo 1>&2 "Usage: spssh_cp.sh [-f 'args'] [-s] [-C 'program'] [-F] [-b] [-e] F/D [RD]"
    test -t 1 || (read -N 1 -sp "Press any key to exit: " && echo " exit")
}

while test "$#" -gt 0; do
    case "$1" in
        -f|--find-args)
            FIND_ARGS="$2"
            shift
            ;;
        -s|--safe-mode)
            SAFE_MODE=true
            ;;
        -b|--begin-no-ask)
            BEGIN_NO_ASK=true
            ;;
        -e|--exit-no-ask)
            EXIT_NO_ASK=true
            ;;
        -C|--compress-program)
            COMPRESS_PROGRAM="$2"
            shift
            ;;
        -F|--fake-tty)
            # combined with spssh.sh --no-tty
            FAKE_TTY=true
            ;;
        -P|--padding-fake-tty)
            FAKE_TTY=true
            PADDING_FAKE_TTY=true
            ;;
        -*)
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
    shift
done
if test "$#" -eq 0; then
    usage
    exit 1
fi

set -e
FILE=`basename "$1"`
SRCDIR=`dirname "$1"`
set +e
DSTDIR=${2:-.}

if test -n "$COMPRESS_PROGRAM" -a "$COMPRESS_PROGRAM" != "none"; then
    COMPRESS_ARGS="-I $COMPRESS_PROGRAM"
fi

if test -z "$ALREADY_RUNNING"; then
    if test -t 0 -a "$BEGIN_NO_ASK" != "true"; then
        sleep 0.1
        read -N 1 -p "Press ENTER to start or any key to cancel: "
        test "$(echo "$REPLY")" != "$(echo)" && echo " exit" && echo 1>&2 && exit
    else
        sleep 1
    fi
fi

function print4k() {
    MSG="$1"
    eval "awk 'BEGIN{ printf \"$MSG\"; for (c=0; c<4095-${#MSG}; c++) { printf \" \" } printf \"\n\" }' | dd bs=4K 2>/dev/null"
}

if test "$SAFE_MODE" = 'true'; then
    RECEIVE_CMD="sed -u '1d;/^$/q'"
    SENTINEL_CMD="echo"
else
    RECEIVE_CMD="stdbuf -i 4K sed '1d;/^ /q'"
    SENTINEL_CMD="print4k; print4k"
fi

echo -e " stty -echo 2>/dev/null; BAK=\$PS1; unset PS1"
sleep 0.5
echo " echo -en Receiving '\"$FILE\" ...\n\r'; mkdir -p '$DSTDIR'; bash -c \"trap 'if test \\\$? -ne 0; then echo; echo -en \\\"Interrupted by user\n\r\\\"; sleep 3; exit 1; fi' EXIT; stty -echo -icanon intr undef 2>/dev/null; $RECEIVE_CMD | base64 -d 2> /dev/null | dd bs=64K iflag=fullblock status=progress 2> >(stdbuf -o0 tr '\r' '\n' | stdbuf -oL grep '/s' | stdbuf -o0 tr '\n' '\r' >&2; echo >&2) | tar x $COMPRESS_ARGS -C '$DSTDIR' 2> /dev/null\" || exit 1"
(cd "$SRCDIR"; print4k; eval find "'$FILE'" "$FIND_ARGS" -print0 | tar cv $COMPRESS_ARGS --null -T - | dd bs=64K | base64 -w 4095; eval "$SENTINEL_CMD"; echo ' stty echo icanon intr ^C 2>/dev/null; PS1=$BAK; unset BAK')

if test "$FAKE_TTY" = "true"; then
    echo " _start"
    if test "$PADDING_FAKE_TTY" = "true"; then
        print4k;print4k;print4k
    fi
fi

if test -z "$ALREADY_RUNNING" -o ! -t 0; then
    if test -t 0; then
        if test "$EXIT_NO_ASK" != "true" -a -z "$TMPDIR"; then
            read -N 1 -p "Exit host REPL and all clients? [y/N] "
            test "$(echo "$REPLY")" != "$(echo)" && echo 1>&2
        else
            REPLY=y
        fi
    else
        REPLY=N
    fi
    REPLY=${REPLY,,}
    if test "$REPLY" != "y"; then
        $(dirname "$0")/spssh.sh --repl --pipe
        EXIT_STATUS=$?
    fi
    if test "$REPLY" = "y" -o "$EXIT_STATUS" != 0; then
        test -t 0 -a -z "$TMPDIR" && echo -e "\n exit"
    fi
fi
