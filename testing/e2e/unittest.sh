#!/bin/bash

# Title        unittset.sh
# Description  Unit test lifecycle for a single test execution
#=============================================================

source ./testing/e2e/utils.sh

function unittest_set_up() {
  utils_timestamp >$TEST_TMPDIR/__test_start
}

function unittest_tear_down() {
  utils_timestamp >$TEST_TMPDIR/__test_end
  utils_log_test_run
}
