#!/bin/bash

# Configure git
git config --global user.email "wix_build_tools@wix.com"
git config --global user.name "Wix"

if [[ -z "${TEST_TMPDIR:-}" ]]; then
  export TEST_TMPDIR="$(mktemp -d ${TMPDIR:-/tmp}/bazel-test.XXXXXXXX)"
fi

if [[ ! -e "${TEST_TMPDIR}" ]]; then
  mkdir -p -m 0700 "${TEST_TMPDIR}"
fi

# Name of current test
TEST_name=""

# All tests log file
TEST_log=$TEST_TMPDIR/log

# Cleanup test environment upon exit
trap 'cleanup' EXIT

function cleanup() {
  # Clean TEST_TMPDIR and verify path contains an identifier before deletion
  if [[ -d ${TEST_TMPDIR} && "${TEST_TMPDIR}" == *"bazel-test"* ]]; then
    rm -rf ${TEST_TMPDIR}
    log_info "Cleaned local test environment"
  else
    log_info "Test environment was cleaned already !"
  fi

  delete_git_cached_directory
}
