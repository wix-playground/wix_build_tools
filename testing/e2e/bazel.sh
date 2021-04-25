#!/bin/bash

function write_workspace_file() {
  cat > "$1" << EOF
workspace(name = "$2")
EOF
}

function create_workspace_with_default_repos() {
  write_workspace_file "${1:-WORKSPACE}" "${2:-wix_build_tools_tests}"
}

function create_new_workspace() {
  new_workspace_dir=${1:-$(mktemp -d ${TEST_TMPDIR}/workspace.XXXXXXXX)}
  rm -rf ${new_workspace_dir} > /dev/null 2>&1
  mkdir -p ${new_workspace_dir}

  cat > ${new_workspace_dir}/BUILD <<EOF
package(default_visibility = ["//visibility:public"])

EOF

  echo $new_workspace_dir
}

function create_clean_workspace() {
  export WORKSPACE_DIR=$(create_new_workspace)
  if [[ ! -d ${WORKSPACE_DIR} ]]; then
    log_fatal "Failed to create a temporary test workspace"
  fi

  custom_workspace_name=$1
  if [[ ! -z ${custom_workspace_name} ]]; then
    create_workspace_with_default_repos ${WORKSPACE_DIR}/WORKSPACE ${custom_workspace_name}
  else
    create_workspace_with_default_repos ${WORKSPACE_DIR}/WORKSPACE
  fi

  copy_git_cached_repo_rules_to_workspace

  bazel clean --expunge
}