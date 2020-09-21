# Simple Parallel SSH

Manage multiple SSH sessions like a boss.

## Usage

You can execute the same command simultaneously or execute different commands separately:

```bash
./spssh.sh user1@example.com user2@example.com [...]  # basic usage
./spssh.sh user@{n1,n2}.example.com  # using shell expansion
./spssh.sh user@n1.example.com user@n2.example.com  # same as above
```

## Drawbacks

SPSSH cannot allocate pseudo-terminal. Some commands cannot be run. But there are some workarounds. For example, use `sudo -S` instead of `sudo`.

## Related Tools

[pssh](https://github.com/lilydjwg/pssh): can only execute the same command.

[clusterssh](https://github.com/duncs/clusterssh): may be better than my simple script. But there are some bugs on my computer.
