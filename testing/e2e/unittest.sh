#!/bin/bash

# Title        unittset.sh
# Description  Unit test lifecycle for a single test execution
#=============================================================

source ./testing/e2e/utils.sh

function unittest_set_up() {
  timestamp >$TEST_TMPDIR/__test_start
}

function unittest_tear_down() {
  timestamp >$TEST_TMPDIR/__test_end
  log_test_run
}
