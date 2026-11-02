#!/usr/bin/env bash
# build/test.sh <prepared source>
#
# Upstream's tests on the prepared source with the pinned Go, as upstream's
# CI runs them: acceptance tests on (TEST_ACCEPTANCE), HTTP answers replayed
# from the recorded cassettes (CI). The container images the acceptance
# tests read must already be in cmd/osv-scanner/scan/image/testdata/
# (upstream's scripts/build_test_images.sh builds them with Docker).
#
# The source must lie under no .gitignore of another repository: the
# scanner reads the .gitignore of every directory from / down to what it
# scans, and an ignore rule above the source hides upstream's test data
# from its own tests. This repository has no .gitignore for that reason.
#
# Two acceptance tests are skipped by name. They scan the AlmaLinux 9 test
# image against osv.dev live (passthrough, not a cassette) and compare the
# result with a snapshot taken when the tag was made; the number of known
# vulnerabilities grows, the snapshot falls behind, and upstream's own CI
# on its main branch fails them the same way. Any other failure stops the
# release. Their snapshots are removed from this test copy of the source
# first: the snapshot library (go-snaps) fails a package in CI over a
# snapshot no test used, and it honours -run but not -skip. The release
# binaries are built elsewhere from an untouched source.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "${HERE}/versions.sh"

# The same two subtests, as -skip matches them and as go-snaps names them.
SKIP='^TestCommand_OCIImage(_JSONFormat)?$/^(Scanning_AlmaLinux_9_image|scanning_almalinux_9_image)$'
SKIPPED=(
  "TestCommand_OCIImage/Scanning_AlmaLinux_9_image"
  "TestCommand_OCIImage_JSONFormat/scanning_almalinux_9_image"
)
SNAPSHOTS="cmd/osv-scanner/scan/image/__snapshots__/command_test.snap"

cd "$1"
require_pinned_go

# A snapshot block is "[<test> - <n>[ - <label>]]", its lines, "---" and an
# empty line. A skipped test without a block here means upstream renamed
# it: the skip list no longer names what it means to, and the run stops.
for test in "${SKIPPED[@]}"; do
  before="$(grep -c "^\[${test} - " "${SNAPSHOTS}" || true)"
  if [ "${before}" -eq 0 ]; then
    echo "ERROR: ${SNAPSHOTS} has no snapshot of ${test}" >&2
    exit 1
  fi
  awk -v prefix="[${test} - " '
    !dropping && index($0, prefix) == 1 { dropping = 1; next }
    dropping && $0 == "---" { dropping = 0; skip_blank = 1; next }
    dropping { next }
    skip_blank && $0 == "" { skip_blank = 0; next }
    { skip_blank = 0; print }
  ' "${SNAPSHOTS}" > "${SNAPSHOTS}.next"
  mv "${SNAPSHOTS}.next" "${SNAPSHOTS}"
  echo "removed ${before} snapshots of ${test} from the test copy"
done
CI=true TEST_ACCEPTANCE=true go test ./... -skip "${SKIP}"
