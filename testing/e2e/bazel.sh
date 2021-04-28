#!/bin/bash

# Title        bazel.sh
# Description  Bazel utilities for setting up a WORKSPACE scoped test environment
#================================================================================

function write_workspace_file() {
  local file_name=$1
  local workspace_name=$2

  export WIX_BUILD_TOOLS_DIR=${TEST_TMPDIR}/wix_build_tools
  cat >"${file_name}" <<EOF
workspace(name = "${workspace_name}")
local_repository(
    name = "wix_build_tools",
    path = "${WIX_BUILD_TOOLS_DIR}",
)
EOF
}

function create_workspace_file_targeting_wix_build_tools() {
  write_workspace_file "${1:-WORKSPACE}" "${2:-wix_build_tools_tests}"
}

function create_new_random_workspace() {
  new_workspace_dir=${1:-$(mktemp -d ${TEST_TMPDIR}/workspace.XXXXXXXX)}
  rm -rf ${new_workspace_dir} >/dev/null 2>&1
  mkdir -p ${new_workspace_dir}

  cat >${new_workspace_dir}/BUILD <<EOF
package(default_visibility = ["//visibility:public"])

EOF

  echo $new_workspace_dir
}

function create_clean_workspace() {
  export WORKSPACE_DIR=$(create_new_random_workspace)
  if [[ ! -d ${WORKSPACE_DIR} ]]; then
    log_fatal "Failed to create a temporary test workspace"
  fi

  custom_workspace_name=$1
  if [[ ! -z ${custom_workspace_name} ]]; then
    create_workspace_file_targeting_wix_build_tools ${WORKSPACE_DIR}/WORKSPACE ${custom_workspace_name}
  else
    create_workspace_file_targeting_wix_build_tools ${WORKSPACE_DIR}/WORKSPACE
  fi
}
