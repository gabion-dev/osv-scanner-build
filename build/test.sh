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
# release.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "${HERE}/versions.sh"

SKIP='^TestCommand_OCIImage(_JSONFormat)?$/^(Scanning_AlmaLinux_9_image|scanning_almalinux_9_image)$'

cd "$1"
require_pinned_go
CI=true TEST_ACCEPTANCE=true go test ./... -skip "${SKIP}"
