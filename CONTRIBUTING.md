### Contributing

Code contributions are welcome!

### Running the tests

The test suite is self-contained (only needs `tmux`, `bash`, `tar`, `find` -
no submodules, no `expect`). Each test spins up its own tmux server on a
private socket and a temporary save directory, so it won't touch your sessions
or saved snapshots. Run it with:

    ./tests/run.sh

### Reporting a bug

If you find a bug please report it in the issues. When reporting a bug please
attach:
- the snapshot a session's `~/.tmux/persist/<session>_last` symlink points to.
- your `.tmux.conf`
- if you're getting an error paste it to a [gist](https://gist.github.com/) and
  link it in the issue
