#!/bin/bash

function copy_git_cached_repo_rules_to_workspace() {
  if [[ -z "${RULES_GIT_DIR:-}" ]]; then
    export RULES_GIT_DIR=${WORKSPACE_DIR}/rules/git
  fi

  if [[ ! -d "${RULES_GIT_DIR}" ]]; then
    mkdir -p -m 0700 "${RULES_GIT_DIR}"
    cp -r ./rules/git/. ${RULES_GIT_DIR}
  fi

  cat >${RULES_GIT_DIR}/BUILD <<EOF
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "git",
    srcs = [
        "BUILD",
    ],
)
EOF
}

function delete_git_cached_directory() {
  cache_dir=$1
  unset RULES_GIT_DIR

  # Clean git cached directory and verify path contains an identifier before deletion
  if [[ (! -z ${cache_dir}) && -d ${cache_dir} && "${cache_dir}" == *"test-git-cache"* ]]; then
    rm -rf ${cache_dir}
  fi

  if [[ -d "${HOME}/.git-cache" ]]; then
    rm -rf "${HOME}/.git-cache"
  fi
}