#!/bin/bash

function set_up() {
  timestamp >$TEST_TMPDIR/__test_start
}

function tear_down() {
  timestamp >$TEST_TMPDIR/__test_end
  log_test_run
}
