<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: Canonical Ltd.
-->
## Inputs

### `image-name`
- **Description:** Name of the Docker image to cache
- **Required:** No
- **Default:** None (if empty, all steps are skipped)

### `mode`
- **Description:** Operating mode - either `save` or `restore`
- **Required:** Yes
- **Options:**
  - `save`: Pull image from Docker Hub, export, compress, and upload as artifact
  - `restore`: Download artifact, decompress, and make available in workspace

**Note:** If `image-name` is empty or not provided, the action does nothing (all steps are skipped).

## Outputs

### `image-path`
- **Description:** Path to the Docker image tar file in the workspace
- **Value:** `docker-cache/docker-image-<sanitized-name>.tar`

## Usage

### Save Mode (in preparation job)

```yaml
- name: Checkout code
  uses: actions/checkout@v6
- name: Save Docker image
  uses: ./.github/actions/docker-image-cache
  with:
    image-name: nginx
    mode: save
```

### Restore Mode (in test jobs)

```yaml
- name: Checkout code
  uses: actions/checkout@v6
- name: Restore Docker image
  uses: ./.github/actions/docker-image-cache
  with:
    image-name: nginx
    mode: restore
```

## Details

On save the action exports selected images to a `docker-cache/` directory in the
workspace.

On restore, the artifacts are downloaded and made available under
`docker-cache/` directory.

Images names follow the pattern: `docker-cache/docker-image-<name>.tar`. Image
names containing `/` or `:` (e.g., `library/nginx:latest`) are mangled like so:
`library/nginx:1.25` -> `docker-image-library-nginx-1.25.tar`

## Example Workflow Structure

```yaml
jobs:
  prepare-docker-image:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: ./.github/actions/docker-image-cache
        with:
          image-name: nginx
          mode: save

  test:
    runs-on: ubuntu-latest
    needs: prepare-docker-image
    steps:
      - uses: actions/checkout@v6
      - uses: ./.github/actions/docker-image-cache
        with:
          image-name: nginx
          mode: restore
      # ... rest of test steps
```
