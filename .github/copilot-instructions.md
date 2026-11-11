<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: Canonical Ltd.
-->

# AI Coding Assistant Instructions for snapd-smoke-tests

## Project Overview
This repository contains integration smoke tests for snapd (the snap package manager) across multiple Linux distributions using the spread testing framework. Tests verify that snapd and various snaps work correctly on different systems.

## Key Architecture Components

### Test Framework
- **spread**: Orchestrates tests across VM images of different Linux distributions
- **image-garden**: Manages cloud VM images for testing (Ubuntu, Fedora, Debian, CentOS, etc.)
- **Test suites**: Organized in `tests/` directory with `desktop/`, `server/`, and `purge/` categories

### Core Files
- `spread.yaml`: Defines test systems, backends, and environment variables
- `run-spread.sh`: Local test runner that iterates through all systems
- `bin/pkgproxy-setup`: Points Docker or LXD in a test VM at pkgproxy, the caching proxy on the host
- `spread/prepare.sh`: System setup script that installs snapd on test VMs
- `spread/install-snapd.sh`: Installs the snapd snap from the risk level under test

## Critical Developer Workflows

### Running Tests Locally
```bash
# Install dependencies: spread and image-garden
# Then run all tests:
./run-spread.sh

# Run tests for specific systems (e.g., only Fedora):
./run-spread.sh fedora

# Run single test suite on specific system:
spread -v ubuntu-cloud-24.04:tests/server/hello/
```

### Test Structure Pattern
Each test in `tests/**/task.yaml` follows this structure:
```yaml
prepare: |
    # Install dependencies (snaps, packages)
    snap install hello
execute: |
    # Run test commands
    snap run hello | MATCH 'Hello, world!'
restore: |
    # Clean up
    snap remove --purge hello
```

### CI/CD Workflow
- GitHub Actions in `.github/workflows/spread.yaml` run tests on all supported distributions
- Uses `zyga/image-garden-action` for VM management
- Configurable snap risk levels via workflow inputs (stable/candidate/beta/edge)

## Project-Specific Conventions

### Environment Variables
- `X_SPREAD_*` prefixed variables configure test behavior
- Examples: `X_SPREAD_SNAPD_RISK_LEVEL`, `X_SPREAD_LOCAL_SNAPD_PKG`
- Set on host system, propagated to test VMs via spread

### Snap Installation and Caching
- Use plain `snap install`, e.g. `snap install --channel=track/risk snapname`
- image-garden sets every VM up to download snaps and apt packages through
  pkgproxy, a caching proxy on the host; image-garden-action keeps its cache in
  the GitHub cache, so there is no caching to do in the tests
- snapd installs bases and default providers by itself; do not install them
  in advance
- For Docker Hub images and LXD images, run `pkgproxy-setup docker` or
  `pkgproxy-setup lxd-remote` after installing the snap. It exits with 1 when
  there is no pkgproxy, so fall back to downloading directly then, and fail on
  any other error. Setting up docker (and apt, snap) needs root; lxd-remote
  (and lxd, snapcraft, go) changes the configuration of the user who runs it,
  and must not run through sudo. Spread runs tasks as root without sudo,
  which suits both

### Test Debugging
- Debug output goes to `*.debug` files (collected by spread's debug handler)
- Use `MATCH` for assertions in test output
- Tests have `kill-timeout` and `warn-timeout` for long-running operations

### Code Quality
- Shell scripts checked with `shellcheck` and formatted with `shfmt`
- YAML formatted with `yamlfmt`
- License compliance checked with `reuse lint`
- Run `make check` before committing

## Integration Points

### External Dependencies
- **snapd**: The system under test, installed via package managers or custom builds
- **image-garden**: VM image management (https://gitlab.com/zygoon/image-garden)
- **spread**: Test framework (https://github.com/snapcore/spread)

### Snap Store Integration
Tests install snaps from store with configurable risk levels:
- snapd, lxd, snapcraft, docker, maas
- Risk levels: stable/candidate/beta/edge

### Custom Build Testing
Support for testing unreleased snapd versions:
- Local packages: Copy to `incoming/` directory, set `X_SPREAD_LOCAL_SNAPD_PKG`
- Debian Salsa CI: Set `X_SPREAD_SALSA_JOB_ID`
- Fedora Bodhi: Set `X_SPREAD_BODHI_ADVISORY_ID`
- AUR: Set `X_SPREAD_ARCH_SNAPD_PR`

## Common Patterns

### Adding New Tests
1. Create `tests/{desktop,server,purge}/newtest/task.yaml`
2. Follow prepare/execute/restore structure
3. Use `snap install` for snap dependencies
4. Add `MATCH` assertions for verification
5. Test locally on one system first

### System-Specific Logic
Use `$SPREAD_SYSTEM` variable in scripts:
```bash
case "$SPREAD_SYSTEM" in
ubuntu-cloud-*)
    apt install -y package
    ;;
fedora-cloud-*)
    dnf install -y package
    ;;
esac
```

### LXD Integration
For tests requiring containers (like snapcraft):
```yaml
prepare: |
    snap install lxd
    snap run lxd waitready
    snap run lxd init --auto
    # Download container images through pkgproxy, when there is one.
    # Exit status 1 means there is no pkgproxy; anything else is an error.
    if pkgproxy-setup lxd-remote; then
        echo pkgproxy-ubuntu >lxd-image-remote
    else
        [ $? -eq 1 ]
        echo ubuntu >lxd-image-remote
    fi
```

Reference files: [`spread.yaml`](spread.yaml), [`bin/pkgproxy-setup`](bin/pkgproxy-setup), [`run-spread.sh`](run-spread.sh), [`tests/server/hello/task.yaml`](tests/server/hello/task.yaml)</content>
<parameter name="filePath">/home/zyga/snapd-smoke-tests/.github/copilot-instructions.md