#!/bin/bash

# Title        assert.sh
# Description  Assertion functions used by testing suites
#=========================================================

function assert_expect_log() {
  local pattern=$1
  local message=${2:-Expected regexp not found. pattern: "'$pattern'"}
  grep -sq -- "$pattern" $TEST_log && return 0

  utils_fail "\nAssertion error: $message"
  return 1
}

function assert_expect_folder() {
  local path=$1
  local message=${2:-"Expected folder not found. path: ${path}"}
  if [[ ! -d ${path} ]]; then
    utils_fail "\nAssertion error: $message"
    return 1
  fi
  return 0
}