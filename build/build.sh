#!/usr/bin/env bash
# build/build.sh <prepared source> <upstream tag> <output directory>
#
# Builds the release binary for every platform of a release from the
# source build/prepare-source.sh left, and names each one as upstream's
# release does: a bare binary osv-scanner_<os>_<amd64|arm64> — the names
# Gabion's installer downloads. Every binary gets a .sha256 file; beside
# them go upstream's LICENSE (Apache-2.0, which asks for its text in a
# binary distribution; upstream's release carries no license file) and the
# module files the binaries were built from.
#
# Go cross-compiles a program without cgo, so the four binaries come from
# one machine and one toolchain. Each is checked before it is published: it
# names the pinned Go and the tag's commit, and a Linux binary is static
# (no program interpreter), so it needs nothing from the host. The
# binaries are reproducible from the same source and Go (-trimpath, the
# commit's date rather than the build's). The script runs on Linux.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "${HERE}/engine.sh"
. "${HERE}/versions.sh"

SOURCE="$(cd "$1" && pwd)"
TAG="$2"
OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
VERSION="${TAG#v}"

require_pinned_go
COMMIT="$(git -C "${SOURCE}" rev-parse HEAD)"
COMMIT_DATE="$(TZ=UTC git -C "${SOURCE}" log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%SZ)"

for target in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64; do
  goos="${target%/*}"
  goarch="${target#*/}"
  file="${BINARY}_${goos}_${goarch}"

  CGO_ENABLED=0 GOOS="${goos}" GOARCH="${goarch}" go build -C "${SOURCE}" \
    -trimpath -ldflags "$(ldflags "${VERSION}" "${COMMIT}" "${COMMIT_DATE}")" -o "${OUT}/${file}" "${MAIN_PACKAGE}"

  info="$(go version -m "${OUT}/${file}")"
  grep -q "^${OUT}/${file}: go${GO_VERSION}\$" <<<"${info}" \
    || { echo "ERROR: ${target}: not built with go${GO_VERSION}" >&2; exit 1; }
  grep -qxF "$(printf '\tbuild\tvcs.revision=%s' "${COMMIT}")" <<<"${info}" \
    || { echo "ERROR: ${target}: does not record the tag's commit ${COMMIT}" >&2; exit 1; }
  if [ "${goos}" = "linux" ] && readelf -l "${OUT}/${file}" | grep -q 'INTERP'; then
    echo "ERROR: ${target}: the binary asks for a program interpreter — it is not static" >&2
    exit 1
  fi

  chmod 0755 "${OUT}/${file}"
  (cd "${OUT}" && sha256sum "${file}" > "${file}.sha256")
  echo "${target}: $(cat "${OUT}/${file}.sha256")"
done

cp "${SOURCE}/LICENSE" "${SOURCE}/go.mod" "${SOURCE}/go.sum" "${OUT}/"
chmod 0644 "${OUT}/LICENSE" "${OUT}/go.mod" "${OUT}/go.sum"
