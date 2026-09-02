#!/usr/bin/env bash
set -euo pipefail

repo_url=https://github.com/lsils/benchmarks.git
revision=82d8cc6910419298e713a46644ed59fd3df53038
destination=${1:-build/public-benchmarks}

if [ -d "$destination/.git" ]; then
  git -C "$destination" fetch --depth 1 origin "$revision"
else
  git clone --quiet --no-checkout --filter=blob:none "$repo_url" "$destination"
fi
git -C "$destination" fetch --quiet --depth 1 origin "$revision"
git -C "$destination" checkout --quiet "$revision" -- random_control/arbiter.v random_control/priority.v
printf 'source=%s\nrevision=%s\n' "$repo_url" "$revision"
