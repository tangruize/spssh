# Simple Parallel SSH

Manage multiple SSH sessions like a boss.

## Usage

SPSSH can execute the same command simultaneously and execute different commands separately on remote servers using SSH.
It supports GUI terminal emulators (e.g. gnome-terminal, mate-terminal and xfce4-terminal) to open remote windows.
And it also supports tmux.
Additionally, there is a simple copy script to copy small files (less than 1GB) to all servers.

### Dependencies

- Host:
  - one of tmux/gnome-terminal/mate-terminal/xfce4-terminal
  - bash, coreutils, util-linux, procps, findutils, openssh-client
  - tar, gzip, zstd, awk (optinoal, for spssh\_cp.sh)
- Clients:
  - tmux (optional, for `--client-tmux` argument)
  - tar, gzip, zstd, sed (optional, for spssh\_cp.sh)

### Basic Usage

```txt
$ ./spssh.sh
Usage: spssh.sh [--tmux/--tmux-detach [auto-exit]]/[--gnome/mate/xfce4-terminal]
                [--client-tmux] user@server1 ['user2@server2 [-p2222 -X ..]' ..]
Usage: spssh.sh --tmux/--tmux-detach [auto-exit]
Usage: spssh.sh --repl [kill-when-exit]

$ spssh_cp.sh
Usage: spssh_cp.sh [--safe-mode] [--begin-no-ask] [--exit-no-ask]
                   [--find-args '-maxdepth 1 -name \*.sh ..']
                   [--compress-program gzip/zstd/..] FILE/DIR [REMOTE_DIR]
        | spssh.sh [options ..] user1@server1 [user2@server2 ..]
Usage: spssh_cp.sh [options ..] FILE/DIR [REMOTE_DIR]  # in tmux session
```

### Examples

```bash
./spssh.sh user1@example1.com user2@example2.com [...]
./spssh.sh user@{n1,n2}.example.com  # use shell expansion, same as user@n1.example.com user@n2.example.com
./spssh.sh "user@n1.example.com -p2222" "user@n2.example.com -p2020 -X"    # add ssh args
./spssh.sh --tmux user@{n1,n2}.example.com  # use tmux backend
./spssh.sh --gnome-terminal user@{n1,n2}.example.com  # use gnome-terminal backend
./spssh.sh --tmux  # open an empty tmux session to add servers later
./spssh.sh --tmux-detach user@example.com  # use tmux backend and run in background
./spssh.sh --client-tmux user@{n1,n2}.example.com  # run tmux in client
./spssh.sh --tmux auto-exit user@{n1,n2}.example.com  # auto exit tmux when all clients are disconnected
./spssh_cp.sh FILE/DIR [REMOTE_DIR] | ./spssh.sh user@{n1,n2}.example.com  # send FILE/DIR to REMOTE_DIR
./spssh_cp.sh FILE/DIR [REMOTE_DIR]  # without piping in tmux backend
./spssh_cp.sh --find-args '-maxdepth 1 -name \*.sh ..' FILE/DIR [REMOTE_DIR]  # filter file to send
```

### Advanced Usage

When using tmux backend, you can create a new panel (`ctrl+b "`),
execute `./spssh.sh user2@example2.com` to add more servers, and execute `./spssh.sh --repl` to open a new host REPL.
You can execute `./spssh_cp.sh FILE/DIR [REMOTE_DIR]` directly without piping to copy files to remote servers.
If using other GUI backends, you should execute `env TMPDIR=/tmp/tmp.xxxxxxxxxx.spssh ./spssh.sh (or ./spssh_cp.sh)`
to achieve the same effect.

If using GUI terminal backends, the host REPL will be closed if all servers are closed.
But in tmux, the host window will not be closed by default.
You can set the argument `auto-exit` after `--tmux/--tmux-detach` to exit the tmux session (actually, panel 0.0)
when all are disconnected.

Set the argument `--client-tmux` to open tmux in the client.
If same clients are connected multiple times, they share the same tmux group
(thus, run `tmux kill-session && exit` to close the window).
If the host REPL exits with Ctrl+D, it kills client SSH connections, but client tmux sessions are still running.

In the host REPL (not piped), press Ctrl + \ (backslash) to toggle line mode and char mode.
In char mode, characters are sent to clients immediately, so that vim can function properly.

Each client SSH is set with the `SSH_NO` environment, which is the ordinal number of the client (starting from 1).
It is useful to determine which client to run which command.

`spssh_cp.sh` can also be piped. For example, you can run
`echo './script.sh; exit' | spssh_cp.sh './script.sh' | ./spssh.sh user@example.com`
to run './script.sh' after sending it.

## Issues

You can [specify `SSH_ASKPASS` program to provide the passphrase](https://stackoverflow.com/a/15090479/9543140),
otherwise ssh will open an GUI window dialog asking for the passphrase.
It is recommended to [config ssh login without password](https://askubuntu.com/a/46935).

If you want to type special chars (e.g. TAB and Ctrl+C) in line mode, first type Ctrl+V and then type TAB (or Ctrl+C).

It is not recommended to use `spssh_cp.sh` for very large files because it is very inefficient
(HOST: tar -> gzip/zstd -> base64; CLIENTS: un-base64 -> un-gzip/zstd -> un-tar; zstd is better).
In the copying progress, you cannot enter any keys in any windows (un-tar will fail and it is treated as interruptions),
you cannot send another file and you cannot add another remote server.

In some circumstances, the `TMPDIR` is not deleted after abnormal exit. You can delete `/tmp/tmp.*.spssh` manually.
It is not necessary to do it because they will be deleted after reboot.

It is not possible to auto resize the terminal size if window size changed,
you can run `stty cols COLUMNS rows LINES` to change it manually.

## Related Tools

[parallel-ssh](https://github.com/ParallelSSH/parallel-ssh)

[clusterssh](https://github.com/duncs/clusterssh)
