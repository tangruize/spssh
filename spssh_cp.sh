#!/bin/bash

# zstd is better than gzip, you should install it on both host and clients before use
#COMPRESS_PROGRAM=zstd
COMPRESS_PROGRAM=${COMPRESS_PROGRAM:-gzip}

#FIND_ARGS="-maxdepth 1 -name \*.sh"
FIND_ARGS=$FIND_ARGS

#BEGIN_NO_ASK=true
BEGIN_NO_ASK=${BEGIN_NO_ASK:-false}

#EXIT_NO_ASK=true
EXIT_NO_ASK=${EXIT_NO_ASK:-false}

# Safe mode is very slow, it solves the stdio buffering problem:
# e.g. echo -e 'a\nb\nc' | (sed '1q'; sed '1q'; sed '1q')           ->  a
#      echo -e 'a\nb\nc' | (sed -u '1q'; sed -u '1q'; sed -u '1q')  ->  a b c
# if safe mode is disabled, it uses big sentinel paddings to feed stdio buffer (in most cases, it is safe enough)
#SAFE_MODE=true
SAFE_MODE=${SAFE_MODE:-false}

if test -t 1 -a -n "$TMPDIR"; then
    env ALREADY_RUNNING=true "$0" $@ >> "$TMPDIR/host"
    exit
fi

function usage() {
    echo 1>&2 "Usage: spssh_cp.sh [--safe-mode] [--begin-no-ask] [--exit-no-ask]"
    echo 1>&2 "                   [--find-args '-maxdepth 1 -name \*.sh ..']"
    echo 1>&2 "                   [--compress-program gzip/zstd/..] FILE/DIR [REMOTE_DIR]"
    echo 1>&2 "        | spssh.sh [options ..] user1@server1 [user2@server2 ..]"
    echo 1>&2 "Usage: spssh_cp.sh [options ..] FILE/DIR [REMOTE_DIR]  # in tmux session"
    test -t 1 || (read -N 1 -sp "Press any key to exit: " && echo " exit")
}

while test "$#" -gt 0; do
    case "$1" in
        -c|--compress-program)
            COMPRESS_PROGRAM="$2"
            shift
            ;;
        -f|--find-args)
            FIND_ARGS="$2"
            shift
            ;;
        -s|--safe-mode)
            SAFE_MODE=true
            ;;
        -e|--exit-no-ask)
            EXIT_NO_ASK=true
            ;;
        -b|--begin-no-ask)
            BEGIN_NO_ASK=true
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

if test -z "$ALREADY_RUNNING"; then
    if test -t 0 -a "$BEGIN_NO_ASK" != "true"; then
        sleep 0.1
        read -N 1 -p "Press ENTER to start or any key to cancel: "
        test "$(echo "$REPLY")" != "$(echo)" && echo " exit" && exit
    else
        sleep 1
    fi
fi

if test "$SAFE_MODE" = 'true'; then
    RECEIVE_CMD="sed -u '/^$/q'"
    SENTINEL_CMD="echo"
else
    RECEIVE_CMD="stdbuf -i 4K sed '/^ /q'"
    SENTINEL_CMD="awk 'BEGIN{ for (b=0; b<2; b++) { for (c=0; c<4095; c++) { printf \" \" } printf \"\n\" } }' | dd bs=4K 2>/dev/null"
fi

echo -e " stty -echo; PSBAK=\$PS1; unset PS1; sleep 0.5"
sleep 0.5
echo " echo Receiving '\"$FILE\" ...'; mkdir -p '$DSTDIR'; bash -c \"stty -echo -icanon intr undef; $RECEIVE_CMD | dd bs=64K iflag=fullblock status=progress | base64 -d 2> /dev/null | tar xv -I $COMPRESS_PROGRAM -C '$DSTDIR' 2> /dev/null || (echo 1>&2 -e '\nInterrupted by user'; sleep 3; exit 1)\" || exit 1"
(cd "$SRCDIR"; eval find "'$FILE'" "$FIND_ARGS" -print0 | tar cv -I $COMPRESS_PROGRAM --null -T - | base64 -w 4095 | dd bs=4K status=progress; eval "$SENTINEL_CMD"; echo " stty echo icanon intr ^C; PS1=\$PSBAK; unset PSBAK")

if test -z "$ALREADY_RUNNING" -o ! -t 0; then
    if test -t 0; then
        if test "$EXIT_NO_ASK" != "true" -a -z "$TMPDIR"; then
            read -N 1 -p "Exit host REPL and all clients? [y/N] "
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
    echo 1>&2
    if test "$REPLY" = "y" -o "$EXIT_STATUS" != 0; then
        test -t 0 -a -z "$TMPDIR" && echo -e "\n exit"
    fi
fi
