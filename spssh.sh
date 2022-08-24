#!/bin/bash

AUTO_EXIT_TMUX=${AUTO_EXIT_TMUX:-false}
DEFAULT_TERM=$DEFAULT_TERM

if test -z "$DISPLAY" -a -z "$DEFAULT_TERM"; then
    DEFAULT_TERM=tmux
fi

terms=($DEFAULT_TERM x-terminal-emulator gnome-terminal mate-terminal xfce4-terminal tmux konsole)
if [ -z "$XTERM" ]; then
    for t in ${terms[*]}; do
        if [ $(command -v $t) ]; then
            export XTERM=$t
            break
        fi
    done
fi

KILL_WHEN_EXIT="kill-when-exit"

function repl {
    if [ "$1" = "pipe" ]; then
        IS_KILL=true
        if [ "$XTERM" = 'tmux' ]; then
            if [ -z "$SESSION" ]; then
                read -p "Enter spssh tmux SESSION: " SESSION
            fi
            if [ -n "$SESSION" ]; then
                tmux select-window -t "$SESSION:0"
                tmux attach-session -d -t "$SESSION"
                exit
            else
                echo 'Warning: no SESSION provided, you should attach and exit tmux manually (or set AUTO_EXIT_TMUX=true)' 1>&2
            fi
        fi
    else
        if [ "$1" = "$KILL_WHEN_EXIT" ]; then
            IS_KILL=true
        fi
        TMPFILE=$TMPDIR/host
        NO_PIPE_ARG='> /dev/null'
    fi
    if [ -n "$TMPFILE" -a -z "$TMPDIR" ]; then
        echo "Error: TMPDIR is not set" 1>&2
        exit
    fi
    if test -t 0; then
        HISTORY=`mktemp --suffix=.history`
        if test "$IS_KILL" = true; then
            echo "Run commands on all servers, Ctrl + D to exit all servers:" 1>&2
        else
            echo "Run commands on all servers, Ctrl + D to exit current repl:" 1>&2
        fi
        stty intr undef
        bash -c "HISTFILE=$HISTORY; set -o history; while read -ep '$ '; do echo \"\$REPLY\" | tee -a $TMPFILE $HISTORY $NO_PIPE_ARG; history -n; done; set +o history; rm -f $HISTORY"
        test "$IS_KILL" = "true" && find $TMPDIR -type p -exec lsof -t {} + | xargs --no-run-if-empty kill
        stty intr ^C
    else
        cat >> $TMPFILE
    fi
}

if test "$#" -eq 0; then
    echo Usage: $0 user1@server1 [user2@server2 ...]
    exit 1
elif [ "$1" = "repl" ]; then
    repl $2
    exit
fi

if [ -z "$XTERM" ]; then
    echo Error: Cannot find a terminal emulator
    exit 1
fi

if test -z "$TMPDIR"; then
    export TMPDIR=`mktemp -d -p /tmp --suffix=.spssh`
    echo "SPSSH: TMPDIR=$TMPDIR" 1>&2
elif test -f "$TMPDIR/host"; then
    ALREADY_RUNNING=true
else
    set -e
    mkdir -p "$TMPDIR"
    set +e
fi
TMPFILE=$TMPDIR/host
touch "$TMPFILE"
RMTMPDIR="rmdir --ignore-fail-on-non-empty $TMPDIR 2> /dev/null"

if test -z "$ALREADY_RUNNING"; then
    trap "echo Quitting ...; trap '' INT TERM" INT TERM
    trap "rm -f $TMPFILE; $RMTMPDIR" EXIT
fi

if [ "$XTERM" = "tmux" ]; then
    if test -z "$ALREADY_RUNNING"; then
        if test -z "$SESSION"; then
            SESSION=SPSSH$((RANDOM%100))
        fi
        export SESSION
        echo "SPSSH: SESSION=$SESSION" 1>&2
        export WIDTH=$(tput cols)
        export HEIGHT=$(($(tput lines)-1))
        set -e
        tmux new-session -d -s "$SESSION" -n "HOST" -x "$WIDTH" -y "$HEIGHT"  " $0 repl $KILL_WHEN_EXIT"
        set +e
    fi
    if test "$AUTO_EXIT_TMUX" != "false"; then
        KILLHOST="tmux kill-window -t $SESSION:0"
    fi
else
    KILLHOST="kill -INT -- -$$"
fi

KILLCAT="pkill -g 0 -x cat"
KILLEXIT="find $TMPDIR -type p -exec false {} + && ($RMTMPDIR; $KILLHOST)"

while test "$#" -gt 0; do
    TMPFIFO=`mktemp -u`
    mkfifo $TMPFIFO
    CMD="bash -c 'stty -echo -echoctl raw; (tail -f $TMPFILE >> $TMPFIFO 2>/dev/null; $KILLCAT) & (setsid ssh -tt $1 < $TMPFIFO; $KILLCAT) & (cat >> $TMPFIFO; rm -f $TMPFIFO; $KILLEXIT)'; exit"
    if test -n "$ALREADY_RUNNING"; then
        truncate -cs 0 "$TMPFILE"
    fi
    case "$XTERM" in
        tmux)
            NAME=$(echo "$1" | grep -o '[^ ]*@[^ ]*' | head -1)_$((RANDOM%100))
            tmux new-window -d -t "$SESSION" -n "$NAME" " $CMD"
            tmux send-keys -t "$SESSION:$NAME" "stty cols $WIDTH rows $HEIGHT" C-m C-l
            ;;
        gnome-terminal)
            eval $XTERM -- $CMD &
            ;;
        *)
            $XTERM -e "$CMD" 2> /dev/null &
            ;;
    esac
    shift
done

if test -z "$ALREADY_RUNNING"; then
    if test -t 0 && [ "$XTERM" = "tmux" ]; then
        tmux select-window -t "$SESSION:0"
        tmux attach-session -d -t "$SESSION"
    else
        repl $KILL_WHEN_EXIT
    fi
fi
