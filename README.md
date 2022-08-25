# Simple Parallel SSH

Manage multiple SSH sessions like a boss.

## Usage

SPSSH can execute the same command simultaneously and execute different commands separately on remote servers using SSH. It supports GUI terminal emulators (e.g. gnome-terminal, mate-terminal and xfce4-terminal) to open remote windows. And it also supports tmux. Additionally, there is a simple copy script to copy small files to all servers.

### Dependencies

- host:
  - one of tmux/gnome-terminal/mate-terminal/xfce4-terminal
  - bash, coreutils, util-linux, procps, findutils, openssh-client
  - tar, gzip, zstd (optinoal, for spssh\_cp.sh)
- client:
  - tmux (optional)
  - tar, gzip, zstd (optional)

### Basic Usage

```txt
$ ./spssh.sh
Usage: ./spssh.sh [tmux/tmux-detach [auto-exit-tmux]]/[gnome/mate/xfce4-terminal] [client-tmux] user1@server1 ['user2@server2 [-p2222 SSH_ARGS]' ...]
       ./spssh.sh tmux/tmux-detach [auto-exit-tmux]
       ./spssh.sh repl [kill-when-exit]

$ spssh_cp.sh
Usage: ./spssh_cp.sh FILE/DIR [REMOTE_DIR] | ./spssh.sh user1@server1 [user2@server2 ...]
       ./spssh_cp.sh FILE/DIR [REMOTE_DIR]  # without piping in tmux session
```

### Examples

```bash
./spssh.sh user1@example1.com user2@example2.com [...]
./spssh.sh user@{n1,n2}.example.com  # use shell expansion, same as user@n1.example.com user@n2.example.com
./spssh.sh "user@n1.example.com -p2222" "user@n2.example.com -p2020"  # add ssh args
./spssh_cp.sh FILE/DIR [REMOTE_DIR] | ./spssh.sh user@{n1,n2}.example.com  # send FILE/DIR to REMOTE_DIR
env DEFAULT_TERM=tmux ./spssh.sh user@{n1,n2}.example.com  # use tmux backend
./spssh.sh tmux user@{n1,n2}.example.com  # use tmux backend, same as above
./spssh.sh gnome-terminal user@{n1,n2}.example.com  # use gnome-terminal backend
./spssh.sh tmux  # open an empty tmux session to add servers later
./spssh.sh tmux-detach user@example.com  # use tmux backend and run in background
./spssh.sh client-tmux user@{n1,n2}.example.com  # run tmux in client
./spssh.sh tmux auto-exit-tmux user@{n1,n2}.example.com  # auto exit tmux when all clients are disconnected
```

### Advanced Usage

When using tmux backend, you can create a new panel (`ctrl+b "`), execute `./spssh.sh user2@example2.com` to add more servers, and execute `./spssh.sh repl` to open a new host REPL. You can execute `./spssh_cp.sh FILE/DIR [REMOTE_DIR]` directly without piping to copy files to remote servers. If using other GUI backends, you should execute `env TMPDIR=/tmp/tmp.xxxxxxxxxx.spssh ./spssh.sh (or ./spssh_cp.sh)` to achieve the same effect.

If using GUI terminal backends, the host REPL will be closed if all servers are closed. But in tmux, the host window will not be closed by default. You can set environment `AUTO_EXIT_TMUX=true` or argument `auto-exit-tmux` to exit the tmux session (actually window 0) when all are disconnected.

Set environment `CLIENT_TMUX=true` or argument `client-tmux` to open tmux in the client. If same clients are connected multiple times, they share the same tmux group. if the host exits with Ctrl+D, it kills client SSH connections, but client tmux sessions are still running.

In the host REPL, press Ctrl + \ (backslash) to toggle line mode and char mode.

You can change the default values of [`AUTO_EXIT_TMUX`](./spssh.sh#L4), [`DEFAULT_TERM`](./spssh.sh#L7-L8) and [`CLIENT_TMUX`](./spssh.sh#L11) in the head of [`spssh.sh`](./spssh.sh).

## Issues

You can [specify `SSH_ASKPASS` program to provide the passphrase](https://stackoverflow.com/a/15090479/9543140),
otherwise ssh will open an GUI window dialog asking for the passphrase.
It is recommended to [config ssh login without password](https://askubuntu.com/a/46935).

If you want to type special chars (e.g. TAB and Ctrl+C), first type Ctrl+V and then type TAB (or Ctrl+C).

It is not recommended to use `spssh_cp.sh` for large files because it is very inefficient (HOST: tar -> gzip/zstd -> base64; CLIENTS: un-base64 -> un-gzip/zstd -> un-tar; zstd is better). In the copying progress, you cannot enter any keys in any windows (Inputs are treated as interruptions), you cannot send another file and you cannot add another remote server.
Use [parallel-scp](https://github.com/ParallelSSH/parallel-ssh) instead.

In some circumstances, the `TMPDIR` is not deleted after abnormal exit. You can delete `/tmp/tmp.*.spssh` manually. But it is not necessary to do it because they will be deleted after reboot.

## Related Tools

[parallel-ssh](https://github.com/ParallelSSH/parallel-ssh)

[clusterssh](https://github.com/duncs/clusterssh)
