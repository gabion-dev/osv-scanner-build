#!/usr/bin/env bash
# build/prepare-source.sh <upstream tag> <directory>
#
# Clones the upstream tag into <directory> (which must not exist), raises
# the modules of build/module-upgrades.txt and tidies the module files
# (`go mod tidy`). What this leaves is the source every binary of a
# release is built from, its tests are run on and its vulnerabilities are
# judged over; the release publishes the resulting go.mod and go.sum, so
# the source can be rebuilt from the upstream tag and those two files.
#
# A listed module the tag already requires at that version or newer stops
# the preparation: the line is obsolete, and `go get` would downgrade the
# module instead of raising it.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "${HERE}/engine.sh"
. "${HERE}/versions.sh"

TAG="$1"
DIR="$2"

require_pinned_go
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "${TAG}" "https://github.com/${UPSTREAM}.git" "${DIR}"
cd "${DIR}"
echo "${UPSTREAM} ${TAG} is commit $(git rev-parse HEAD)"

while read -r spec reason; do
  case "${spec}" in '' | '#'*) continue ;; esac
  module="${spec%@*}"
  wanted="${spec#*@}"
  required="$(go list -m -f '{{.Version}}' "${module}")"
  if [ "${required}" = "${wanted}" ]; then
    echo "ERROR: ${TAG} already requires ${module} ${wanted}; remove its line from build/module-upgrades.txt" >&2
    exit 1
  fi
  output="$(go get "${spec}" 2>&1)"
  echo "${output}"
  if grep -q 'downgraded' <<<"${output}"; then
    echo "ERROR: ${TAG} requires ${module} ${required}, newer than ${wanted}; remove its line from build/module-upgrades.txt" >&2
    exit 1
  fi
  if [ "$(go list -m -f '{{.Version}}' "${module}")" != "${wanted}" ]; then
    echo "ERROR: ${module} did not resolve to ${wanted}" >&2
    exit 1
  fi
  echo "raised ${module} ${required} -> ${wanted}: ${reason}"
done < "${HERE}/module-upgrades.txt"

go mod tidy
echo "Module files against the tag:"
git --no-pager diff -- go.mod go.sum
