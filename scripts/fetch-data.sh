#!/usr/bin/env bash
# Clone the workload repo at the pinned commit into data/mockito (shallow, no line-ending conversion).
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=mockito/mockito
SHA=10b31ba2a8252cf340bc154c9e05224802a84691
DIR=data/mockito
if [ -d "$DIR" ]; then
  if [ "$(git -C "$DIR" rev-parse HEAD 2>/dev/null)" = "$SHA" ]; then echo "already at $SHA"; exit 0; fi
  echo "$DIR exists but is not at $SHA. Remove it yourself and run again." >&2; exit 1
fi
git init -q "$DIR"
git -C "$DIR" config core.autocrlf false
git -C "$DIR" remote add origin "https://github.com/$REPO.git"
git -C "$DIR" fetch -q --depth 1 origin "$SHA"
git -C "$DIR" checkout -q FETCH_HEAD
echo "cloned $REPO at $(git -C "$DIR" rev-parse HEAD)"
