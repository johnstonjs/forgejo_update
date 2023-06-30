# forgejo_update_script

A script to automatically update [forgejo](https://forgejo.org) installed on local
host to the latest release.

## Installation

Place in an appropriate location on local host and execute on schedule via cron.

## Dependencies

Requires some basic shell commands listed in the script, and assumes that
`systemd` is used to start/stop forgejo.

Assumes that forgejo is executed from a symlink specified in $DIR.  The actual
forgejo binaries are placed in $DIR/bin.  This script will automatically update
the symlink when a new verson is downloaded.
