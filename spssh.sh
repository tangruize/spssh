#!/bin/bash

# To automatically exit tmux when all servers are closed
#AUTO_EXIT_TMUX=true
AUTO_EXIT_TMUX=${AUTO_EXIT_TMUX:-false}

#DEFAULT_TERM=tmux
#DEFAULT_TERM=gnome-terminal
DEFAULT_TERM=$DEFAULT_TERM

#CLIENT_TMUX=true
CLIENT_TMUX=${CLIENT_TMUX:-false}

if test -z "$DISPLAY" -a -z "$DEFAULT_TERM"; then
    DEFAULT_TERM=tmux
fi

# konsole is incompatible (when using vim, tmux ...), consider it as the last one to use
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
        if [ -z "$SESSION" ]; then
            if [ -d "$TMPDIR" ]; then
                SESSION=SPSSH$(echo -n "${TMPDIR%.spssh}" | tail -c2)
            else
                test -t 0 && read -p "Enter last two chars of tmux SESSION (press ENTER if backend is not tmux): " SESSION
                SESSION=${SESSION:+SPSSH${SESSION#SPSSH}}
            fi
        fi
        if [ -n "$SESSION" ]; then
            tmux select-window -t "$SESSION:0" 1>&2
            tmux attach-session -d -t "$SESSION" 1>&2 && exit
        fi
    else
        if [ "$1" = "$KILL_WHEN_EXIT" ]; then
            IS_KILL=true
        fi
        TMPFILE=$TMPDIR/host
        SEQFILE=$TMPDIR/seq
        NO_PIPE_ARG='> /dev/null'
    fi
    if [ -n "$TMPFILE" -a -z "$TMPDIR" ]; then
        echo "Error: TMPDIR is not set" 1>&2
        exit 1
    fi
    if test -t 0; then
        HISTORY=`mktemp --suffix=.history`
        echo -n "Run commands on all servers" 1>&2
        if test "$IS_KILL" = true; then
            echo ", Ctrl + D to exit all servers, Ctrl + \\ to switch line/char mode:" 1>&2
        elif test "$1" = "pipe"; then
            echo ", Ctrl + D to exit all servers:" 1>&2
        else
            echo ", Ctrl + D to exit current repl, Ctrl + \\ to switch line/char mode:" 1>&2
        fi
        trap "rm -f $HISTORY; test '$IS_KILL' = true && rm -f $TMPFILE $SEQFILE 2>/dev/null; test -d "$TMPDIR" && rmdir --ignore-fail-on-non-empty "$TMPDIR" 2> /dev/null" EXIT
        stty intr undef
        bash -c "m=l; trap 'echo; echo -n Presss ENTER to switch to\ ; if test \$m = l; then m=c; echo char mode; else m=l; s=1; echo line mode; fi' QUIT; HISTFILE=$HISTORY; set -o history; cmr() { read -N 1 r; }; cme() { echo -n \"\$r\"; }; lmr() { read -ep '$ ' r; }; lme() { if test \"\$s\" = 1; then true; else echo \"\$r\"; fi; }; while eval \\\${m}mr; do eval \\\${m}me | tee -a $TMPFILE $HISTORY $NO_PIPE_ARG; history -n; unset s; done; set +o history"
        if test "$IS_KILL" = "true"; then
            find $TMPDIR -type p -exec lsof -t {} + | xargs --no-run-if-empty kill
        fi
        stty intr ^C
    else
        if test "$1" =  "pipe"; then
            cat
        else
            cat >> $TMPFILE
        fi
    fi
    if [ "$1" = "pipe" ]; then
        exit 1
    fi
}

while test "$#" -gt 0; do
    if [[ "$1" =~ ^(gnome|mate|xfce4)-terminal$ ]] || [ "$1" = "tmux" ]; then
        export XTERM=$1
    else
        case "$1" in
            background|tmux-detach)
                XTERM=tmux
                BACKGROUND=true
                ;;
            client-tmux)
                CLIENT_TMUX=true
                ;;
            auto-exit-tmux)
                AUTO_EXIT_TMUX=true
                ;;
            *)
                break
                ;;
        esac
    fi
    HAS_ARG=true
    shift
done

if test "$#" -eq 0 && (test -z "$HAS_ARG" || test "$XTERM" != "tmux"); then
    echo "Usage: $0 [tmux/tmux-detach [auto-exit-tmux]]/[gnome/mate/xfce4-terminal] [client-tmux] user1@server1 ['user2@server2 [-p2222 -X SSH_ARGS ...]' ...]"
    echo "       $0 tmux/tmux-detach [auto-exit-tmux]"
    echo "       $0 repl [$KILL_WHEN_EXIT]"
    exit 1
elif [ "$1" = "repl" ]; then
    repl $2
    exit
fi

if [ -z "$(command -v $XTERM)" ]; then
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
SEQFILE=$TMPDIR/seq
touch "$TMPFILE" "$SEQFILE"
RMTMPDIR="rmdir --ignore-fail-on-non-empty $TMPDIR 2> /dev/null"

if test -z "$ALREADY_RUNNING"; then
    trap "echo Quitting ...; trap '' INT TERM" INT TERM
    if test "$XTERM" != "tmux"; then
        trap "rm -f $TMPFILE $SEQFILE 2>/dev/null; $RMTMPDIR" EXIT
    fi
fi

if test -z "$SESSION"; then
    export SESSION=SPSSH$(echo -n "${TMPDIR%.spssh}" | tail -c2)
fi

if [ "$XTERM" = "tmux" ]; then
    if test -z "$ALREADY_RUNNING"; then
        echo "SPSSH: SESSION=$SESSION" 1>&2
        export WIDTH=$(tput cols)
        export HEIGHT=$(($(tput lines)-1))
        set -e
        if ! tmux has-session -t "$SESSION" 2>/dev/null; then
            tmux new-session -d -s "$SESSION" -n "HOST" -x "$WIDTH" -y "$HEIGHT" -e "AUTO_EXIT_TMUX=$AUTO_EXIT_TMUX" -e "DEFAULT_TERM=$DEFAULT_TERM" -e "CLIENT_TMUX=$CLIENT_TMUX" -e "TMPDIR=$TMPDIR" -e "DISPLAY=$DISPLAY" -e "SESSION=$SESSION" -e "WIDTH=$WIDTH" -e "HEIGHT=$HEIGHT" "$0 repl $KILL_WHEN_EXIT"
        elif test -n "$TMUX_PANE"; then
            CURRENT_IN_TMUX=true
        else
            tmux split-window -t "$SESSION:0" " $0 repl $KILL_WHEN_EXIT"
        fi
        set +e
    fi
    if test "$AUTO_EXIT_TMUX" != "false"; then
        KILLHOST="tmux kill-window -t $SESSION:0"
    fi
else
    KILLHOST="kill -INT -- -$$"
fi

function set_ssh_cmd() {
    SSH_START_CMD_=
    SSH_NO=$1
    if [ "$CLIENT_TMUX" = true ]; then
        SSH_NAME_PREFIX=SSH$(echo -n $SESSION | tail -c 2)
        SSH_NAME=$SSH_NAME_PREFIX$(echo -n $(mktemp -u) | tail -c 2)
        TMUX_CLIENT_ENV="-e SSH_NO=$SSH_NO -e SSH_CLIENT=\\\"\\\$SSH_CLIENT\\\" -e SSH_CONNECTION=\\\"\\\$SSH_CONNECTION\\\" -e SSH_TTY=\\\"\\\$SSH_TTY\\\" -e DISPLAY=\\\"\\\$DISPLAY\\\""
        SSH_START_CMD_=" tmux new-session -t $SSH_NAME_PREFIX -s $SSH_NAME_PREFIX $TMUX_CLIENT_ENV 2>/dev/null || (tmux new-session -d -t $SSH_NAME_PREFIX -s $SSH_NAME $TMUX_CLIENT_ENV; tmux new-window -t $SSH_NAME; tmux attach-session -t $SSH_NAME); exit"
    fi

    if [ -n "$SSH_START_CMD_" -a "$XTERM" = "tmux" ]; then
        TMUX_SEND_KEYS="${SSH_START_CMD_//\\/}"
        unset SSH_START_CMD_
    fi

    SSH_START_CMD="${SSH_START_CMD_:+\"${SSH_START_CMD_}\"}"
    SSH_START_CMD="${SSH_START_CMD:-\"export SSH_NO=$SSH_NO; \\\$SHELL -i\"}"
}

KILLCAT="pkill -g 0 -x cat"
KILLEXIT="find $TMPDIR -type p -exec false {} + && ($RMTMPDIR; $KILLHOST)"

while test "$#" -gt 0; do
    TMPFIFO=`mktemp -u --suffix=.ssh`
    #SEQ=$(find "$TMPDIR" -maxdepth 1 -name '*ssh*' | sed -En 's/.*\.ssh\.([0-9])/\1/p' | sort -n | tail -1)
    SEQ=$(cat $SEQFILE)
    SEQ=$((SEQ+1))
    echo $SEQ > "$SEQFILE"
    TMPFIFO=${TMPFIFO}.$((SEQ))
    mkfifo $TMPFIFO
    set_ssh_cmd $SEQ
    CMD="bash -c 'stty -echo -echoctl raw; (tail -f $TMPFILE >> $TMPFIFO 2>/dev/null; $KILLCAT) & (setsid ssh -tt $1 $SSH_START_CMD < $TMPFIFO; $KILLCAT) & (cat >> $TMPFIFO; rm -f $TMPFIFO; $KILLEXIT)'; exit"
    if test -n "$ALREADY_RUNNING"; then
        truncate -cs 0 "$TMPFILE"
    fi
    NAME=$(echo "$1" | grep -o '[^ ]*@[^ ]*' | head -1 | tr '.' '_')_${TMPFIFO##*.}
    case "$XTERM" in
        tmux)
            tmux new-window -d -t "$SESSION" -n "$NAME" " $CMD"
            tmux send-keys -t "$SESSION:$NAME" " stty cols $WIDTH rows $HEIGHT" C-m C-l
            test -n "$TMUX_SEND_KEYS" && tmux send-keys -t "$SESSION:$NAME" "$TMUX_SEND_KEYS" C-m
            ;;
        gnome-terminal)
            eval $XTERM --title="$NAME" -- $CMD & sleep 0.1
            ;;
        *)
            $XTERM --title="$NAME" -e "$CMD" 2> /dev/null & sleep 0.1
            ;;
    esac
    shift
done

if test -z "$ALREADY_RUNNING"; then
    if test -t 0 -a "$XTERM" = "tmux" -a -z "$CURRENT_IN_TMUX"; then
        tmux select-window -t "$SESSION:0"
        if test "$BACKGROUND" != "true"; then
            tmux attach-session -d -t "$SESSION"
        fi
    else
        repl $KILL_WHEN_EXIT
    fi
fi
