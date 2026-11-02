# build/versions.sh
#
# The toolchain every release of this repository is built and judged with,
# sourced by the workflow and by a local run of the scripts in build/. The
# scripts refuse any other Go: GOTOOLCHAIN=local keeps a go.mod from
# switching it silently. Renovate proposes new releases (the renovate:
# lines); a new Go is a new revision of the release built with it.

# renovate: datasource=golang-version depName=go
GO_VERSION="1.27.3"

# renovate: datasource=go depName=golang.org/x/vuln
GOVULNCHECK_VERSION="v1.9.0"

export GOTOOLCHAIN=local

# Stops unless the go on PATH is the pinned release.
require_pinned_go() {
  local actual
  actual="$(go env GOVERSION)"
  if [ "${actual}" != "go${GO_VERSION}" ]; then
    echo "ERROR: build/versions.sh pins go${GO_VERSION}, the go on PATH is ${actual}" >&2
    exit 1
  fi
}
