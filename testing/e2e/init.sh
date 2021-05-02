#!/bin/bash

# Title        init.sh
# Description  Test suite lifecycle for creating / tearing down a temp test environment
#======================================================================================

source ./testing/e2e/logging.sh
source ./testing/e2e/git_rules_utils.sh

configure_git_client

function copy_wix_build_tools_to_test_env() {
  test_dir=$1
  export WIX_BUILD_TOOLS_DIR=${test_dir}/wix_build_tools
  mkdir -p -m 0700 ${WIX_BUILD_TOOLS_DIR}
  # TODO: Need to ignore .git folder
  cp -r . ${test_dir}/wix_build_tools
}

if [[ -z "${TEST_TMPDIR:-}" ]]; then
  export TEST_TMPDIR="$(mktemp -d ${TMPDIR:-/tmp}/bazel-test.XXXXXXXX)"
  log_info "Test environment created at ${TEST_TMPDIR}"
  copy_wix_build_tools_to_test_env ${TEST_TMPDIR}
fi

if [[ ! -e "${TEST_TMPDIR}" ]]; then
  # Create a test directory if does not exists
  mkdir -p -m 0700 "${TEST_TMPDIR}"
fi

# Name of current test
TEST_name=""

# All tests log file
TEST_log=$TEST_TMPDIR/log

# Cleanup test environment upon exit
trap 'clean_test_environment' EXIT

function clean_test_environment() {
  # Clean TEST_TMPDIR and verify path contains an identifier before deletion
  if [[ -d ${TEST_TMPDIR} && "${TEST_TMPDIR}" == *"bazel-test"* ]]; then
    rm -rf ${TEST_TMPDIR}
    unset TEST_TMPDIR
    log_info "Cleaned local test environment"
  else
    log_info "Test environment was cleaned already !"
  fi

  delete_git_cached_directory
}
