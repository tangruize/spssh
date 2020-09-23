# Simple Parallel SSH

Manage multiple SSH sessions like a boss.

## Usage

SPSSH can execute the same command simultaneously and execute different commands separately:

```bash
./spssh.sh user1@example1.com user2@example2.com [...]  # basic usage
./spssh.sh user@{n1,n2}.example.com  # use shell expansion
./spssh.sh user@n1.example.com user@n2.example.com  # same as above
./spssh.sh "user@n1.example.com -p2222" "user@n2.example.com -p2020"  # add ssh args
```

## Issues

You can [specify `SSH_ASKPASS` program to provide the passphrase](https://stackoverflow.com/a/15090479/9543140), otherwise ssh will open an X11 window dialog asking for the passphrase.
It is recommended to [config ssh login without password](https://askubuntu.com/a/46935).

## Related Tools

[pssh](https://github.com/lilydjwg/pssh): can only execute the same command.

[clusterssh](https://github.com/duncs/clusterssh): has some bugs on my computer.
