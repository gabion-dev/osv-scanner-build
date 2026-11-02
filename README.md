# osv-scanner-build (Linux and macOS, amd64 / arm64)

[OSV-Scanner](https://github.com/google/osv-scanner) rebuilt from its own
release tags with the newest Go release, for the dependency checker of the
[Gabion](https://github.com/gabion-dev) framework. Gabion downloads these
binaries itself; the binaries do not need Gabion.

This project is not affiliated with, endorsed by, or sponsored by Google or
the OSV-Scanner authors.

## Why a rebuild

A Go program carries the standard library of the Go release it was built
with. Upstream's v2.7.0 binaries were built with Go 1.27.0; Go 1.27.2 and
1.27.3 fixed vulnerabilities in the standard library, and govulncheck finds
vulnerable functions of those bulletins called by upstream's build. Rebuilt
from the same tag with the Go of [`build/versions.sh`](build/versions.sh), it
calls none. A module with a called vulnerability would be raised in
[`build/module-upgrades.txt`](build/module-upgrades.txt); for v2.7.0 none is.

Nothing else changes: the flags, the version, commit and date strings, the
main package, the absence of cgo and the file names are those of upstream's
release recipe (`.goreleaser.yml` at the tag, the build `osv-scanner`).

## Releases

A release tag is `<upstream tag>-r<revision>`, for example `v2.7.0-r1`:
OSV-Scanner v2.7.0, revision 1 of this recipe for it. A new Go release or a
new module upgrade for the same upstream tag is a new revision; a published
revision is never rebuilt.

Each release has four bare binaries, named as upstream's, each with a
`.sha256` file next to it:

- `osv-scanner_linux_amd64` — Linux x64, static
- `osv-scanner_linux_arm64` — Linux ARM64, static
- `osv-scanner_darwin_amd64` — macOS 13+, Intel
- `osv-scanner_darwin_arm64` — macOS 13+, Apple Silicon

`LICENSE` is upstream's license text at the tag. `go.mod` and `go.sum` are
the module files every binary was built from: the upstream tag with these two
files is the source of the release. The binaries carry a build provenance
attestation:

```sh
gh attestation verify osv-scanner_linux_amd64 --repo gabion-dev/osv-scanner-build
```

Upstream's own release is signed with SLSA provenance by Google's release
workflow; that provenance names upstream's binaries, not these. These are
attested by the workflow of this repository instead.

## How a release is made

The workflow [Build OSV-Scanner](.github/workflows/build.yml) runs by hand
from the Actions tab with the upstream tag and the revision. The scripts in
[`build/`](build/) do the work, in the workflow and on a developer machine
alike:

1. `prepare-source.sh` clones the upstream tag, raises the modules of
   `module-upgrades.txt` and tidies the module files, as upstream's release
   does;
2. `vulnerability-gate.sh` runs govulncheck over the release binary's main
   package for linux and darwin and stops the release when any bulletin's
   vulnerable function is called — naming the bulletin, the module and the
   version that fixes it;
3. `build.sh` builds the four binaries without cgo on one Linux machine and
   checks that each names the pinned Go and the tag's commit, and that the
   Linux ones are static;
4. upstream's tests run on the same source as upstream's CI runs them —
   acceptance tests on, recorded HTTP answers — on Ubuntu 24.04 and macOS 15;
5. `launch-check.sh` starts every binary on a machine of its own system and
   architecture: it must report the tag's version and find a known
   vulnerability in an offline scan of a CycloneDX bill of materials against
   the Maven export of osv.dev. Linux x64 and ARM64 run on the runner and in
   clean Ubuntu 22.04, Debian 13, Fedora and Alpine containers; macOS on 15
   and 26, Apple Silicon and Intel.

Only then is the release published.

## Source and license

OSV-Scanner is licensed under the Apache License 2.0; each release carries
the text as its `LICENSE` asset. The scripts and workflow of this repository
are under the [Apache License 2.0](LICENSE) as well.
