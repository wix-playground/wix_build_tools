#!/bin/bash

# Title        git_rules_testkit.sh
# Description  Test kit for glueing together Bazel wiring and git_cached repo rules
#==================================================================================

source ./testing/e2e/bazel.sh

function recreate_git_cached_rule_for_small_repo() {
  # Re-create WORKSPACE file and re-declare git_cached_repository with the new commit hash
  create_workspace_file_targeting_wix_build_tools "${WORKSPACE_DIR}/WORKSPACE"
  create_git_cached_rule_for_small_repo "$@" # forwards args as one string per argument
}

function create_git_cached_rule_for_small_repo() {
  local newline="\r\n"
  local spaces="    "
  while [[ "$#" -gt 0 ]]
  do
    case "$1" in
      commit*)
        local commit="${newline}${spaces}${1},"
        shift
        ;;
      remote_url*)
        local remote_url="${newline}${spaces}${1},"
        shift
        ;;
      branch*)
        local branch="${newline}${spaces}${1},"
        shift
        ;;
      cache_directory*)
        local cache_directory="${newline}${spaces}${1},"
        shift
        ;;
      fetch_retries_count*)
        local fetch_retries_count="${newline}${spaces}${1},"
        shift
        ;;
      fetch_retry_timeout_in_sec*)
        local fetch_retry_timeout_in_sec="${newline}${spaces}${1},"
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  # Set defaults
  commit=${commit="${newline}${spaces}commit = missing-commit-hash,"}  # no defaults for commit hash
  remote_url=${remote_url="${newline}${spaces}remote_url = '${REPO_SMALL_DIR}',"}
  branch=${branch="${newline}${spaces}branch = 'master',"}
  cache_directory=${cache_directory=''} # use rule default if none supplied
  fetch_retries_count=${fetch_retries_count=''} # use rule default if none supplied
  fetch_retry_timeout_in_sec=${fetch_retry_timeout_in_sec=''} # use rule default if none supplied

  # Trim consecutive // characters since Bazel would fail if such exists on a target path
  local trimmed_path=$(echo ${WORKSPACE_DIR} | tr -s '/')

  echo -e """
load(\"@wix_build_tools//rules/git:git_cached_repository.bzl\", \"git_cached_repository\")
git_cached_repository(
    name = \"small_repo\",${commit}${remote_url}${branch}${cache_directory}${fetch_retries_count}${fetch_retry_timeout_in_sec}
)
""" >> ${WORKSPACE_DIR}/WORKSPACE

  if [[ "${GIT_CACHED_RULES_VERBOSE}" == "True" ]]; then
    cat ${WORKSPACE_DIR}/WORKSPACE
  fi
}

function create_sh_lib_ref_small_repo() {
  target_name=quote_reader_lib
  target_label="//quotes:${target_name}"

  mkdir -p quotes
  cat >quotes/BUILD.bazel <<EOF
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
  target_label="//quotes:${target_name}"

  mkdir -p quotes
  cat >quotes/BUILD.bazel <<EOF
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
