#!/bin/bash

# Title        git_rules.sh
# Description  Utilities for managing git cache / git client
#============================================================

function configure_git_client() {
  GIT_USER=$(/usr/bin/git config --global --get user.name)
  if [[ -z ${GIT_USER} ]]; then
    /usr/bin/git config --global user.email "testing@git.com"
  fi

  GIT_EMAIL=$(/usr/bin/git config --global --get user.email)
  if [[ -z ${GIT_EMAIL} ]]; then
    /usr/bin/git config --global user.name "Testing"
  fi
}

function define_git_rules_env_vars() {
  dir_name=$(basename ${WORKSPACE_DIR})
  export TEST_GIT_CACHE_DIR=${TEST_TMPDIR}/git-cache-${dir_name}
}

function delete_git_cached_directory() {
  cache_dir=$1

  # Clean git cached directory and verify path contains an identifier before deletion
  if [[ (! -z ${cache_dir}) && -d ${cache_dir} && "${cache_dir}" == *"git-cache-workspace"* ]]; then
    rm -rf ${cache_dir}
  fi

  if [[ -d "${HOME}/.git-cache" ]]; then
    rm -rf "${HOME}/.git-cache"
  fi
}
