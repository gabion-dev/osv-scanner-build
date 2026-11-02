#!/bin/sh
# build/launch-check.sh <binary> <version> <database directory>
#
# The launch check of a release binary, on a machine of its own system and
# architecture: it must report the version of the tag it was built from
# and find a known vulnerability the way Gabion's dependency checker runs
# it — offline, against a local database, over a CycloneDX bill of
# materials with a Maven group (log4j-core 2.14.1, GHSA-jfh8-c2jp-5v3q).
# <database directory> holds the Maven export of osv.dev in the layout the
# scanner reads: osv-scalibr/Maven/all.zip. POSIX sh and no tool beyond
# grep, so it runs in a bare container too.

set -eu

BINARY="$1"
VERSION="$2"
DATABASE="$3"

REPORTED="$("${BINARY}" --version 2>&1)"
echo "${REPORTED}"
if ! printf '%s\n' "${REPORTED}" | grep -qxF "osv-scanner version: ${VERSION}"; then
  echo "ERROR: the binary does not report version ${VERSION}" >&2
  exit 1
fi

WORK="$(mktemp -d)"
cat > "${WORK}/application.cdx.json" <<'EOF'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "version": 1,
  "components": [
    {
      "type": "library",
      "group": "org.apache.logging.log4j",
      "name": "log4j-core",
      "version": "2.14.1",
      "purl": "pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1"
    }
  ]
}
EOF

STATUS=0
"${BINARY}" scan source --offline --local-db-path "${DATABASE}" --format json \
  --output-file "${WORK}/report.json" --lockfile "${WORK}/application.cdx.json" || STATUS=$?
if [ "${STATUS}" -ne 1 ]; then
  echo "ERROR: the scan exited ${STATUS}, a finding exits 1" >&2
  exit 1
fi
if ! grep -q 'GHSA-jfh8-c2jp-5v3q' "${WORK}/report.json"; then
  echo "ERROR: the report does not name GHSA-jfh8-c2jp-5v3q:" >&2
  cat "${WORK}/report.json" >&2
  exit 1
fi
echo "the offline scan found GHSA-jfh8-c2jp-5v3q"
rm -rf "${WORK}"
