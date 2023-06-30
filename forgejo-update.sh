#!/bin/sh
# A shell script to automatically update Forejo
# Depends only on basic shell utilities (curl, cut, find, grep, sed)
# Assumes use of systemd for Forgejo start/stop


DIR=/usr/local/bin/forgejo   # Set location of forgejo binary on local system
URL=https://codeberg.org/forgejo/forgejo/releases
ARCH=linux-amd64            # Set architecture type:
                            # darwin-10.6.386 darwin-10.6-amd64 linux-386
                            # linux-arm-5,6,7,arm64,mips,mips64,mips64le
USER=root                   # User for file permissions on forgejo binary
GROUP=git                   # Group for file permissions on forgejo binary
INIT_TYPE=systemd           # Specify init script type (only systemd now)
SERVICE=git		    # Specify the name of systemd script
PRUNE=1                     # If TRUE, script will delete older versions
RC=0                        # If TRUE, script will download Release Candidates
DEBUG=1                     # If TRUE, debug messages are printed to STDOUT

get_latest_release() {
# forgejo check adapted from:
# https://codeberg.org/forgejo/forgejo/src/branch/forgejo/contrib/upgrade.sh
curl --connect-timeout 10 -sL 'https://codeberg.org/api/v1/repos/forgejo/forgejo/releases?draft=false&pre-release=false&limit=1' -H 'accept: application/json' | jq -r '.[0].tag_name | sub("v"; "")'
}

get_current_version() {
  eval $1 -v | cut -d " " -f 3
}

# Set variable #new_ver by checking release status from forgejo
NEW_VER=$(get_latest_release)
if [ $DEBUG -eq 1 ]; then
  echo "New Version:    $NEW_VER"
fi

# Check if new version is a Release Candidate (contains "-rc")
case $NEW_VER in *-rc*)
  if [ $RC -eq 0 ]; then
    if [ $DEBUG -eq 1 ]; then
      echo "New Version is Release Candidate, quitting"
    fi
  exit 0
  fi
esac

# Check if forgejo binary exists at specified $FILE
if test -f "$DIR/forgejo"; then
  if [ $DEBUG -eq 1 ]; then
    echo "$DIR/forgejo exists"
  fi
else
  echo "ERROR: $DIR/forgejo does not exist"
  exit 0
fi

# Check current version
CUR_VER=$(get_current_version $DIR/forgejo)

if [ $DEBUG -eq 1 ]; then
  echo "Current Version: $CUR_VER"
fi

if [ $NEW_VER != $CUR_VER ]; then
  if [ $DEBUG -eq 1 ]; then
    echo "There is a newer release available, downloading..."
  fi
  # Download the latest version of forgejo compressed binary
  binname="forgejo-${NEW_VER}-${ARCH}"
  binbase="https://codeberg.org/forgejo/forgejo/releases/download/v${NEW_VER}/"
  binurl="https://codeberg.org/forgejo/forgejo/releases/download/v${NEW_VER}/${binname}.xz"
  echo "Downloading $binurl..."
  cd "$DIR/bin"
  ( cd $DIR/bin && curl --connect-timeout 10 --silent --show-error --fail --location -O "$binurl" )

  # Verify the checksum of the latest forgejo compressed binary
  SHA_CHECK=$(cd $DIR/bin && curl -s -L "${binurl}.sha256" | sha256sum -c | cut -d " " -f 2)
  if [ $SHA_CHECK = "OK" ]; then
    if [ $DEBUG -eq 1 ]; then
      echo "SHA256 verified"
    fi
  else
    echo "ERROR: SHA256 check failed"
    exit 0
  fi

  # Decompress downloaded compressed binary
  if [ $DEBUG -eq 1 ]; then
    echo "Decompressing ${binname}.xz"
  fi
  xz --decompress --force "${binname}.xz"

  # Set USER/GROUP ownership for new forgejo binary
  chown $USER:$GROUP $DIR/bin/forgejo-$NEW_VER-$ARCH
  # Set permissions for new forgejo binary (rwxr-x---)
  chmod 0750 $DIR/bin/forgejo-$NEW_VER-$ARCH
  # Stop the forgejo service
  case $INIT_TYPE in
    systemd)
      service $SERVICE stop
      ;;
    *)
  esac
  # Update the symlink at $DIR/forgejo to pint to latest forgejo binary
  ln -sf $DIR/bin/forgejo-$NEW_VER-$ARCH $DIR/forgejo
  # Start the forgejo service
  case $INIT_TYPE in
    systemd)
      service $SERVICE start
      ;;
    *)
  esac
  if [ $PRUNE -eq 1 ]; then
    find $DIR/bin/ -maxdepth 1 -type f ! -newer $DIR/bin/forgejo-$CUR_VER-$ARCH ! \
    -wholename $DIR/bin/forgejo-$CUR_VER-$ARCH -delete
  fi
  if [ $DEBUG -eq 1 ]; then
    echo "forgejo upgraded to v$NEW_VER"
  fi
else
  if [ $DEBUG -eq 1 ]; then
    echo "The latest version is already installed"
    exit 1
  fi
fi
