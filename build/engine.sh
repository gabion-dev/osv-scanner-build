# build/engine.sh
#
# What this repository builds, sourced by every script in build/. The
# values are upstream's own release recipe (.goreleaser.yml at the tag,
# the build of id osv-scanner): a release binary built here differs from
# upstream's only in the Go release it is built with and in the modules of
# build/module-upgrades.txt.

# The repository whose release tags are built.
UPSTREAM="google/osv-scanner"

# The release binary and its main package, relative to the source root.
BINARY="osv-scanner"
MAIN_PACKAGE="./cmd/osv-scanner"

# Upstream's release binaries are built without build tags.
BUILD_TAGS=""

# The ldflags of upstream's release: the version is the tag without its
# "v", the commit and its date (UTC, RFC 3339) those of the tag.
ldflags() {
  echo "-s -w -X github.com/google/osv-scanner/v2/internal/version.OSVVersion=$1 -X github.com/google/osv-scanner/v2/cmd/osv-scanner/internal/cmd.commit=$2 -X github.com/google/osv-scanner/v2/cmd/osv-scanner/internal/cmd.date=$3"
}
