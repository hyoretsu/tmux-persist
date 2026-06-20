### Contributing

Code contributions are welcome!

### Running the tests

The test suite is self-contained (only needs `tmux`, `bash`, `tar`, `find` -
no submodules, no `expect`). Each test spins up its own tmux server on a
private socket and a temporary save directory, so it won't touch your sessions
or saved snapshots. Run it with:

    ./tests/run.sh

### Publishing a release

Releases are plain git tags (tmux/TPM installs from a branch or tag - there is
nothing to publish to a package registry). To cut version `vX.Y.Z`:

1. Bump the version in `CHANGELOG.md`: add a `### vX.Y.Z, YYYY-MM-DD` heading at
   the top with the notes for this release. Follow semver - a breaking change
   (renamed option, changed save format, etc.) bumps the major.
2. Commit it:

       git commit -am "release: vX.Y.Z"

3. Tag the release (annotated) and push the branch and the tag:

       git tag -a vX.Y.Z -m "vX.Y.Z"
       git push origin main
       git push origin vX.Y.Z

4. Create the GitHub release from the tag (this is what users see under
   "Releases"):

       gh release create vX.Y.Z --title "vX.Y.Z" --notes-from-tag

   (or use the GitHub web UI: Releases -> Draft a new release -> pick the tag).

Users on TPM (`set -g @plugin 'hyoretsu/tmux-persist'`) track the default
branch, so they get changes on their next `prefix + I` update; the tag/release
is the human-facing version marker and lets people pin a specific version.

### Reporting a bug

If you find a bug please report it in the issues. When reporting a bug please
attach:
- the snapshot a session's `~/.tmux/persist/<session>_last` symlink points to.
- your `.tmux.conf`
- if you're getting an error paste it to a [gist](https://gist.github.com/) and
  link it in the issue
