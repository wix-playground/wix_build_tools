#!/bin/bash

# Title        git_rules_testkit.sh
# Description  Test kit for glueing together Bazel wiring and git_cached repo rules
#==================================================================================

source ./testing/e2e/bazel.sh

function recreate_git_cached_rule_for_small_repo() {
  # Re-create WORKSPACE file and re-declare git_cached_repository with the new commit hash
  create_workspace_file_targeting_wix_build_tools "${WORKSPACE_DIR}/WORKSPACE"
  local commit_hash=$1
  local cache_dir=${2:-"default-dir"}
  create_git_cached_rule_for_small_repo ${commit_hash} ${cache_dir}
}

function create_git_cached_rule_for_small_repo() {
  local commit_hash=$1
  local cache_dir=${2:-"default-dir"}

  # Trim consecutive // characters since Bazel would fail if such exists on a target path
  local trimmed_path=$(echo ${WORKSPACE_DIR} | tr -s '/')

  if [[ ${cache_dir} == "default-dir" ]]; then
    cat >>${WORKSPACE_DIR}/WORKSPACE <<EOF
load("@wix_build_tools//rules/git:git_cached_repository.bzl", "git_cached_repository")
git_cached_repository(
    name = "small_repo",
    remote_url = "${REPO_SMALL_DIR}",
    commit = "${commit_hash}",
    branch = "master",
)
EOF
  else
    cat >>${WORKSPACE_DIR}/WORKSPACE <<EOF
load("@wix_build_tools//rules/git:git_cached_repository.bzl", "git_cached_repository")
git_cached_repository(
    name = "small_repo",
    remote_url = "${REPO_SMALL_DIR}",
    commit = "${commit_hash}",
    branch = "master",
    cache_directory = "${cache_dir}",
)
EOF
  fi
}

function create_sh_lib_ref_small_repo() {
  target_name=quote_reader_lib
  target_label="//quotes:${target_name}"

  mkdir -p quotes
  cat >quotes/BUILD <<EOF
package(default_visibility = ["//visibility:public"])
sh_library(
    name = "${target_name}",
    data = ["@small_repo//quotes:movies"],
)
EOF

  echo ${target_label}
}

function create_sh_binary_ref_small_repo() {
  target_name=quote_reader
  target_label="quotes:${target_name}"

  mkdir -p quotes
  cat >quotes/BUILD <<EOF
package(default_visibility = ["//visibility:public"])
sh_binary(
    name = "${target_name}",
    srcs = ["quote_reader.sh"],
    data = ["@small_repo//quotes:movies"],
)
EOF

  cat >quotes/quote_reader.sh <<EOF
#!/bin/sh
cat ../small_repo/quotes/the_wizard_of_oz.txt
EOF
  chmod +x quotes/quote_reader.sh

  echo ${target_label}
}

function create_new_commit_on_small_repo() {
  # Create a new commit on the repo in test
  cwd=$(pwd)
  cd ${REPO_SMALL_DIR}
  echo "correct dorothy, we are in bazel world" >${REPO_SMALL_DIR}/quotes/the_wizard_of_oz.txt
  /usr/bin/git add "quotes/the_wizard_of_oz.txt" >>${TEST_log}
  /usr/bin/git commit -m "Updated a quote to generate a new commit" >>${TEST_log}
  new_commit=$(/usr/bin/git log -n 1 --pretty=format:%H)
  cd $cwd

  echo ${new_commit}
}
