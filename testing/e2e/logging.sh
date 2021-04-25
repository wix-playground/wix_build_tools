#!/bin/bash

function __show_log() {
  echo "-- Tests invocation log: -----------------------------------------------"
  [[ -e $TEST_log ]] && cat $TEST_log || echo "(Could not find log file.)"
  echo "------------------------------------------------------------------------"
}

function _log_base() {
  prefix=$1
  shift
  echo -e $(date "+%Y-%m-%d %H:%M:%S") "${prefix} [$(basename "$0")] $*" >&2
}

function log_info() {
  _log_base "INFO     " "$@"
}

function log_warning() {
  _log_base "WARNING  " "$@"
}

function log_error() {
  _log_base "ERROR    " "$@"
}

function log_fatal() {
  _log_base "ERROR    " "$@"
  exit 1
}
