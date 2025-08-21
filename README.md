<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: Canonical Ltd.
-->
# Snapd smoke tests

This project provides integration tests for running upcoming snapd releases
across a matrix of many different operating systems against a selection of
representative snaps.

The following distributions are tested on x86\_64 hardware:

- Amazon Linux (2 and 2023)
- Arch Linux
- CentOS (9 and 10)
- Debian (11, 12, 13 and sid)
- Fedora (41 and 42)
- Ubuntu (LTSes since 20.04, devel releases and upcoming release)
- openSUSE (Tumbleweed with AppArmor)

If you are running on aarch64 hardware, you can run the same tests locally,
except for Arch Linux, as there is no upstream cloud image for Arch yet.

All distribution images are provided by their respective upstream projects.
Images are downloaded and initialized with cloud-init using
[image-garden](https://gitlab.com/zygoon/image-garden).

All tests are implemented with [spread](https://github.com/snapcore/spread).

To run tests locally install the `image-garden` snap and then run the
`run-spread.sh` script from the root of the project. For optimal performance
you may need to use _edge_ channel for both snapd snap and image-garden until
image-garden 0.4 and snapd 2.71 are released.

## Testing builds from https://salsa.debian.org/debian/snapd

Grab the GitLab job ID for the "build" job of a pipeline that ran on
https://salsa.debian.org/debian/snapd and either invoke the GitHub workflow
"salsa", passing to it the ID or run spread locally with
`X_SPREAD_SALSA_JOB_ID=` environment variable set.

Note that this is only compatible with `debian-cloud-sid` spread system.

## Testing Debian package updates with locally-built snapd

Build snapd for the matching CPU architecture and copy `snapd_*.deb` file to
the `incoming/` directory of the `snapd-smoke-tests` project. Then set the
environment variable `X_SPREAD_LOCAL_SNAPD_PKG` to the name of the file you've
copied and run spread.

## Testing builds from https://bodhi.fedoraproject.org/

Grab the advisory number from the Fedora update system (e.g.
`FEDORA-2025-737127f363`) and either invoke the GitHub workflow passing the ID
or run spread locally with `X_SPREAD_BODHI_ADVISORY_ID=` environment variable
set.

Note that the advisory is only compatible with a given release of Fedora or
EPEL, so you must be careful in selecting the system to pair it with.

## Testing snapd AUR updates

AUR does not have support for pull-requests, so it is advisable to host a
separate repository mirroring the AUR one on GitHub or Gitlab. Open a PR and set
`X_SPREAD_ARCH_SNAPD_PR` with an URL to the PR. If the repository is managed
with [aurpublish](https://github.com/eli-schwartz/aurpublish), you can set
`X_SPREAD_ARCH_REPO_SUBDIR` to point to the directory where snapd packaging
files are located.

## Testing snapd openSUSE packages

By default snapd will be installed from the `system:snappy` OBS project. One can
set `X_SPREAD_OPENSUSE_OBS_PROJECT` to run tests with snapd package from a
custom OBS project, e.g. `X_SPREAD_OPENSUSE_OBS_PROJECT=home:my_user_on_obs:branches:system:snappy`.

## Testing Amazon Linux packages

By default snapd will be installed from a community repository hosted at
https://bboozzoo.github.io/snapd-amazon-linux.

The artifacts provided in that repository are built using tooling from
https://github.com/bboozzoo/snapd-amazon-linux. The repository tarballs
generated with the tooling can be directly consumed by the smoke test suite by
setting `X_SPREAD_AMAZON_REPO_FILE` to the relative path of the `*.tar.xz*`
repository tarball. For example:

```sh
X_SPREAD_AMAZON_REPO_FILE=./amazon-linux-2-repo.tar.xz  spread -v garden:amazonlinux-cloud-2023:tests/server/...
```
