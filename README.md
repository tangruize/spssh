# Simple Parallel SSH

Manage multiple SSH sessions like a boss.

## Usage

SPSSH can execute the same command simultaneously and execute different commands separately:

```bash
./spssh.sh user1@example1.com user2@example2.com [...]  # basic usage
./spssh.sh user@{n1,n2}.example.com  # use shell expansion
./spssh.sh user@n1.example.com user@n2.example.com  # same as above
./spssh.sh "user@n1.example.com -p2222" "user@n2.example.com -p2020"  # add ssh args
./spssh_cp.sh FILE/DIR [REMOTE_DIR] | ./spssh.sh user@{n1,n2}.example.com  # send FILE/DIR to REMOTE_DIR
```

## Issues

You can [specify `SSH_ASKPASS` program to provide the passphrase](https://stackoverflow.com/a/15090479/9543140),
otherwise ssh will open an X11 window dialog asking for the passphrase.
It is recommended to [config ssh login without password](https://askubuntu.com/a/46935).

If you want to type special chars (e.g. TAB and Ctrl+C), first type Ctrl+V and then type TAB (or Ctrl+C).

It is not recommended to use `spssh_cp.sh` for large files because it is very inefficient.
Use [parallel-scp](https://github.com/ParallelSSH/parallel-ssh) instead.

## Related Tools

[parallel-ssh](https://github.com/ParallelSSH/parallel-ssh): can only execute the same command and is not interactive.

[clusterssh](https://github.com/duncs/clusterssh): has bugs on my computer.
