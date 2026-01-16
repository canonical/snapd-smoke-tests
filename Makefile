# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
.PHONY: check fmt fmt-sh fmt-yaml check-shfmt check-shellcheck check-yaml check-reuse test

check: check-shellcheck check-shfmt check-reuse test
fmt: fmt-sh fmt-yaml

SCRIPTS_SH=bin/snap-install $(wildcard spread/*.sh) run-spread.sh
# https://github.com/mvdan/sh
check-shfmt:
	shfmt --diff $(SCRIPTS_SH)
fmt-sh:
	shfmt --write $(SCRIPTS_SH)

# https://www.shellcheck.net/
check-shellcheck:
	shellcheck $(SCRIPTS_SH)

# https://github.com/google/yamlfmt
check-yamlfmt:
	yamlfmt -lint -dstar **/*.yaml  .github/*/*.yaml
fmt-yaml:
	yamlfmt -dstar **/*.yaml .github/*/*.yaml

# https://reuse.software/
check-reuse:
	reuse lint

# Run Python unit tests
test:
	python3 test_analyze_spread_logs.py
