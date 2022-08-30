#!/bin/bash

# To automatically exit tmux when all servers are closed
#TMUX_AUTO_EXIT=true
TMUX_AUTO_EXIT=${TMUX_AUTO_EXIT:-false}

# Not to attach to tmux session
#TMUX_DETACH=true
TMUX_DETACH=${TMUX_DETACH:-false}

#DEFAULT_TERM=tmux
#DEFAULT_TERM=gnome-terminal
DEFAULT_TERM=$DEFAULT_TERM

# Client SSH run tmux
#CLIENT_TMUX=true
CLIENT_TMUX=${CLIENT_TMUX:-false}

# GUI terminal geometries
#GEOMETRIES=(80x24 110x28 ..)
GEOMETRIES=(${GEOMETRY[@]})

# Use `script` to create a fake tty
#FAKE_TTY=true
FAKE_TTY=${FAKE_TTY:-false}

# Not to allocate tty (fast for sending files)
#NO_TTY=true
NO_TTY=${NO_TTY:-false}

# If stdin is not tty, use NO_TTY
#NO_TTY_IF_PIPED=true
NO_TTY_IF_PIPED=${NO_TTY_IF_PIPED:-false}
if test "$NO_TTY_IF_PIPED" = "true" -a ! -t 0; then
    NO_TTY=true
fi

if test -z "$DISPLAY" -a -z "$DEFAULT_TERM"; then
    DEFAULT_TERM=tmux
fi

terms=($DEFAULT_TERM x-terminal-emulator gnome-terminal konsole mate-terminal xfce4-terminal tmux)
if [ -z "$XTERM" ]; then
    for t in ${terms[*]}; do
        if [ $(command -v $t) ]; then
            export XTERM=$t
            break
        fi
    done
fi

REPL_KILL_WHEN_EXIT="--kill-when-exit"
REPL_PIPE="--pipe"

function repl {
    if [ "$1" = "$REPL_PIPE" ]; then
        if [ -z "$SESSION" ]; then
            if [ -d "$TMPDIR" ]; then
                SESSION=SPSSH$(echo -n "${TMPDIR%.spssh}" | tail -c2)
            else
                test -t 0 && read -p "Enter last two chars of tmux SESSION (press ENTER if backend is not tmux): " SESSION
                SESSION=${SESSION:+SPSSH${SESSION#SPSSH}}
            fi
        fi
        if [ -n "$SESSION" -a -t 0 ]; then
            if tmux select-window -t "$SESSION:0" 1>&2; then
                test "$FAKE_TTY" = "true" && tmux new-window -d -t "$SESSION" " W=\$(tput cols); H=\$(tput lines); echo \" [ -z \\\"\\\$TMUX_PANE\\\" -a -z \\\"\\\$SSH_TTY\\\" -a \\\"\\\$TERM\\\" = 'xterm-256color' ] && stty cols \$W rows \$H\" >\"\$TMPDIR/host\"" 1>&2
                tmux select-pane -t "$SESSION:0.0"
                tmux attach-session -d -t "$SESSION" 1>&2 && exit
            fi
        fi
    else
        if [ "$1" = "$REPL_KILL_WHEN_EXIT" ]; then
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
        if test "$IS_KILL" = true -o "$1" = "$REPL_PIPE"; then
            echo ", Ctrl + D to exit all servers, Ctrl + \\ to switch line/char mode:" 1>&2
        else
            echo ", Ctrl + D to exit current repl, Ctrl + \\ to switch line/char mode:" 1>&2
        fi
        trap "rm -f $HISTORY; test '$IS_KILL' = true && rm -f $TMPFILE $SEQFILE 2>/dev/null; test -d "$TMPDIR" && rmdir --ignore-fail-on-non-empty "$TMPDIR" 2> /dev/null" EXIT
        stty intr undef
        bash -c "m=l; function resize() { if test -n \"\$TMUX_PANE\"; then W=\$(tput cols); H=\$(tput lines); echo \" stty cols \$W rows \\\$(test -z \\\$TMUX_PANE && echo \$H || echo \$((H-1)))\"; fi }; trap 'echo 1>&2; echo 1>&2 -n Presss ENTER to switch to\ ; if test \$m = l; then m=c; echo 1>&2 char mode; else m=l; s=1; echo 1>&2 line mode; fi' QUIT; HISTFILE=$HISTORY; set -o history; cmr() { read -rN 1 r; }; cme() { echo -n \"\$r\"; }; lmr() { read -rep '$ ' r; }; lme() { if test \"\$s\" = 1; then true; elif test \"\$r\" = '#RESIZE'; then resize; else echo \"\$r\"; fi; }; while eval \\\${m}mr; do eval \\\${m}me | tee -a $TMPFILE $HISTORY $NO_PIPE_ARG; history -n; unset s; done; set +o history"
        if test "$IS_KILL" = "true"; then
            find $TMPDIR -type p -exec lsof -t {} + | xargs --no-run-if-empty kill
        fi
        stty intr ^C
    else
        trap '' QUIT
        if test "$1" = "$REPL_PIPE"; then
            cat
        else
            cat >> "$TMPFILE"
        fi
        trap QUIT
    fi
    if [ "$1" = "$REPL_PIPE" ]; then
        exit 1
    fi
}

function usage() {
    echo "Usage: spssh.sh [--tmux [--detach --auto-exit --run-host-cmd 'host cmd']]"
    echo "                [--gnome/mate/xfce4-terminal/konsole [--geometry 80x24+0+0 ..]]"
    echo "                [--client-tmux] [--compress] [--fake-tty] [--no-tty]"
    echo "                'user1@server1 [SSH_ARGS ..]' .."
    echo "Usage: spssh.sh --tmux [--detach --auto-exit --run-host-cmd ' host cmd']"
    echo "Usage: spssh.sh --repl [$REPL_KILL_WHEN_EXIT]  # in tmux session"
    echo "Usage: spssh.sh [-t [-d -e -r 'cmd']]/[-g/-m/-x/-k [-G ..]] [-c] [-C] [-F/-N] .."
}

while test "$#" -gt 0; do
    case "$1" in
        -g|--gnome-terminal)
            export XTERM=gnome-terminal
            ;;
        -k|--konsole)
            export XTERM=konsole
            ;;
        -m|--mate-terminal)
            export XTERM=mate-terminal
            ;;
        -x|--xfce4-terminal)
            export XTERM=xfce4-terminal
            ;;
        -t|--tmux)
            export XTERM=tmux
            while test -n "$2"; do
                case "$2" in
                    -d|--detach)
                        TMUX_DETACH=true
                        shift
                        ;;
                    -e|--auto-exit)
                        TMUX_AUTO_EXIT=true
                        shift
                        ;;
                    -r|--run-host-cmd)
                        TMUX_RUN_HOST_CMD="$3"
                        shift 2
                        ;;
                    -n|--no-change-prefix-with-client-tmux)
                        TMUX_NO_CHANGE_PREFIX=true
                        shift
                        ;;
                    *)
                        break
                        ;;
                esac
            done
            ;;
        -c|--client-tmux)
            CLIENT_TMUX=true
            ;;
        -G|--geometry)
            GEOMETRIES=(${GEOMETRIES[@]} $2)
            shift
            ;;
        -R|--repl)
            if test "$2"; then
                if test "$2" != "$REPL_KILL_WHEN_EXIT" -a "$2" != "$REPL_PIPE"; then
                    usage
                    exit 2
                fi
            fi
            repl $2
            exit
            ;;
        -C|--compress)
            SSH_ARGS+=' -C'
            ;;
        -F|--fake-tty)
            # seems useless
            FAKE_TTY=true
            ;;
        -N|--no-tty)
            # very fast for sending files, combined with spssh_cp.sh --fake-tty
            NO_TTY=true
            ;;
        -*)
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
    HAS_ARG=true
    shift
done

if test "$#" -eq 0 && (test -z "$HAS_ARG" || test "$XTERM" != "tmux"); then
    usage
    exit 1
fi

if test "$FAKE_TTY" != "true" -a "$NO_TTY" != "true"; then
    SSH_ARGS+=' -tt'
else
    SSH_ARGS+=' -T'
    if test "$NO_TTY" = "true"; then
        CLIENT_TMUX=false
        FAKE_TTY=false
    fi
fi

if [ -z "$(command -v $XTERM)" ]; then
    echo Error: Cannot find a terminal emulator
    exit 1
fi

set -e
if test -z "$TMPDIR"; then
    TMPDIR=`mktemp -d -p /tmp --suffix=.spssh`
    export TMPDIR
    echo "[SPSSH] TMPDIR=$TMPDIR" 1>&2
elif test -f "$TMPDIR/host"; then
    ALREADY_RUNNING=true
else
    mkdir -p "$TMPDIR"
fi
set +e
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
        echo "[SPSSH] SESSION=$SESSION" 1>&2
        export WIDTH=$(tput cols || echo 80)
        export HEIGHT=$(($(tput lines || echo 24)-1))
        set -e
        if ! tmux has-session -t "$SESSION" 2>/dev/null; then
            if test "$CLIENT_TMUX" = "true"; then
                TMUX_MOUSE_OPTION="tmux set-option mouse off;"
                if test "$TMUX_NO_CHANGE_PREFIX" != "true"; then
                    TMUX_CHANGE_PREFIX="tmux set-option prefix C-a; tmux bind C-a send-prefix;"
                fi
            fi
            tmux new-session -d -s "$SESSION" -n "HOST" -x "$WIDTH" -y "$HEIGHT" -e "TMUX_AUTO_EXIT=$TMUX_AUTO_EXIT" -e "DEFAULT_TERM=$DEFAULT_TERM" -e "CLIENT_TMUX=$CLIENT_TMUX" -e "TMPDIR=$TMPDIR" -e "DISPLAY=$DISPLAY" -e "SESSION=$SESSION" -e "WIDTH=$WIDTH" -e "HEIGHT=$HEIGHT" "bash -c 'set -x; $TMUX_MOUSE_OPTION $TMUX_CHANGE_PREFIX'; $0 --repl $REPL_KILL_WHEN_EXIT"
        elif test -n "$TMUX_PANE"; then
            CURRENT_IN_TMUX=true
        else
            tmux split-window -t "$SESSION:0" "$0 --repl $REPL_KILL_WHEN_EXIT"
        fi
        set +e
    fi
    if test "$TMUX_AUTO_EXIT" != "false"; then
        KILLHOST="tmux kill-pane -t $SESSION:0.0"
    fi
    if test "$TMUX_RUN_HOST_CMD"; then
        tmux split-window -t "$SESSION:0"
        tmux send-keys -t "$SESSION:0" "$TMUX_RUN_HOST_CMD" C-l C-m
    fi
    STTY_CMD=" stty cols $WIDTH rows $HEIGHT;"
else
    KILLHOST="kill -INT -- -$$"
fi

function set_geometry() {
    if [ "$XTERM" = "tmux" ]; then
        return
    fi
    unset GEOMETRY_OPTIONS
    if test "$CLIENT_TMUX" = 'true'; then
        DEFAULT_HEIGHT=25
    else
        DEFAULT_HEIGHT=24
    fi
    GEOMETRY=${GEOMETRIES[0]:-80x$DEFAULT_HEIGHT}
    if [ "${#GEOMETRIES[@]}" -gt 1 ]; then
        unset GEOMETRIES[0]
        GEOMETRIES=(${GEOMETRIES[@]})
    fi
    XSIZE=($(tr '[+x\-]' ' ' <<< "$GEOMETRY"))
    WIDTH=${XSIZE[0]:-80}
    HEIGHT=${XSIZE[1]:-$DEFAULT_HEIGHT}
    if [ "$XTERM" = "konsole" ]; then
        # konsole (v22.04.1) may increase/decrease the row by 1...
        if [ -n "${XSIZE[2]}" -a -n "${XSIZE[3]}" ]; then
            GEOMETRY_OPTIONS="--geometry $(sed -E 's/[0-9]+x[0-9]+(.*)/\1/' <<< "$GEOMETRY")"
        fi
    fi
    if [ "$NO_TTY" != "true" ]; then
        STTY_CMD=" stty cols $WIDTH rows $HEIGHT;"
    fi
}

function set_ssh_cmd() {
    SSH_START_CMD=
    SSH_NO=$1
    if [ "$CLIENT_TMUX" = true ]; then
        SSH_NAME_PREFIX=SSH$(echo -n $SESSION | tail -c 2)
        SSH_NAME=$SSH_NAME_PREFIX$(echo -n $(mktemp -u) | tail -c 2)
        TMUX_CLIENT_ENV="-x $WIDTH -y $((HEIGHT-1)) -e SSH_NO=$SSH_NO -e SSH_CLIENT=\\\"\\\$SSH_CLIENT\\\" -e SSH_CONNECTION=\\\"\\\$SSH_CONNECTION\\\" -e SSH_TTY=\\\"\\\$SSH_TTY\\\" -e DISPLAY=\\\"\\\$DISPLAY\\\""
        SSH_START_CMD="$STTY_CMD if tmux new-session -d -t $SSH_NAME_PREFIX -s $SSH_NAME_PREFIX $TMUX_CLIENT_ENV 2>/dev/null; then tmux attach-session -t $SSH_NAME_PREFIX; else tmux new-session -d -t $SSH_NAME_PREFIX -s $SSH_NAME $TMUX_CLIENT_ENV; tmux new-window -t $SSH_NAME; tmux attach-session -t $SSH_NAME; fi; exit"
    fi

    SSH_START_CMD="${SSH_START_CMD:-$STTY_CMD env SSH_NO=$SSH_NO \\\$SHELL}"

    if [ "$FAKE_TTY" = "true" ]; then
        SSH_START_CMD="env TERM=xterm-256color script -qc \\\"${SSH_START_CMD//\\/\\\\\\}\\\" /dev/null"
    fi
}

KILLCAT="pkill -g 0 -x cat"
KILLEXIT="find $TMPDIR -type p -exec false {} + && ($RMTMPDIR; $KILLHOST)"

while test "$#" -gt 0; do
    TMPFIFO=`mktemp -u --suffix=.ssh`
    SEQ=$(cat $SEQFILE)
    SEQ=$((SEQ+1))
    echo $SEQ > "$SEQFILE"
    TMPFIFO=${TMPFIFO}.$((SEQ))
    mkfifo $TMPFIFO
    set_geometry
    set_ssh_cmd $SEQ
    CMD="bash -c 'stty -echo -echoctl raw; (tail -f $TMPFILE >> $TMPFIFO 2>/dev/null; $KILLCAT) & (setsid ssh $SSH_ARGS $1 \"$SSH_START_CMD\" < $TMPFIFO; $KILLCAT) & (cat >> $TMPFIFO; rm -f $TMPFIFO; $KILLEXIT)'; exit"
    if test -n "$ALREADY_RUNNING"; then
        truncate -cs 0 "$TMPFILE"
    fi
    NAME=$(echo "$1" | grep -o '[^ ]*@[^ ]*' | head -1 | tr '.' '_')_${TMPFIFO##*.}
    case "$XTERM" in
        tmux)
            tmux new-window -d -t "$SESSION" -n "$NAME" "$CMD"
            ;;
        gnome-terminal)
            eval $XTERM --geometry="$GEOMETRY" --title="$NAME" -- $CMD & sleep 0.1
            ;;
        konsole)
            $XTERM -p "tabtitle=$NAME" -p "TerminalColumns=$WIDTH" -p "TerminalRows=$HEIGHT" $GEOMETRY_OPTIONS -e "$CMD" & sleep 0.1
            ;;
        *)
            $XTERM --geometry="$GEOMETRY" --title="$NAME" -e "$CMD" & sleep 0.1
            ;;
    esac
    shift
done

if test -z "$ALREADY_RUNNING"; then
    if test -t 0 -a "$XTERM" = "tmux" -a -z "$CURRENT_IN_TMUX"; then
        tmux select-window -t "$SESSION:0"
        tmux select-pane -t "$SESSION:0.0"
        if test "$TMUX_DETACH" != "true"; then
            tmux attach-session -d -t "$SESSION"
        fi
    else
        repl $REPL_KILL_WHEN_EXIT
    fi
elif ! test -t 0; then
    repl
fi
