#!/bin/bash

# Title        utils.sh
# Description  General utilities
#===============================

source ./testing/e2e/logging.sh

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_WHITE='\033[1;37m'
COLOR_NONE='\033[0m'

function fail() {
  timestamp >$TEST_TMPDIR/__test_end
  TEST_passed="false"
  log_test_run
  echo "$@" >$TEST_TMPDIR/__fail
  echo -e "$@" >>${TEST_log}
  __show_log >&2
  exit 1
}

function timestamp() {
  echo $(date +%s)
}

function get_run_time() {
  local ts_start=$1
  local ts_end=$2
  run_time_sec=$((${ts_end} - ${ts_start}))
  echo $run_time_sec
}

function log_test_run() {
  local ts_start=$(cat $TEST_TMPDIR/__test_start)
  local ts_end=$(cat $TEST_TMPDIR/__test_end)
  run_time=$(get_run_time $ts_start $ts_end)

  if [[ "$TEST_passed" == "true" ]]; then
    log_info "${COLOR_GREEN}PASSED${COLOR_NONE}: $TEST_name ($run_time sec)" >&2
  else
    log_error "${COLOR_RED}FAILED${COLOR_NONE}: $TEST_name ($run_time sec)" >&2
  fi
}

function log_tests_suite_header() {
  msg=$1
  log_info "${COLOR_WHITE}RUNNING${COLOR_NONE}: ${msg}"
}

function log_test_name() {
  name=$1
  log_info ${name}...
}
