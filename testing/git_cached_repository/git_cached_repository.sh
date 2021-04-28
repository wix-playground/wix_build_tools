#!/bin/bash

source ./testing/e2e/init.sh # Must be sourced 1st
source ./testing/e2e/bazel.sh
source ./testing/e2e/unittest.sh
source ./testing/e2e/repos_loader.sh
source ./testing/e2e/git_rules_utils.sh
source ./testing/e2e/git_rules_testkit.sh
source ./testing/e2e/assert.sh
source ./testing/e2e/utils.sh

# Must be invoked from the root of the repo.
ROOT=$PWD

function before_test() {
  unittest_set_up
  TEST_name=$1
  TEST_passed="true"
  create_clean_workspace
  define_git_rules_env_vars
  log_test_name ${TEST_name}
  # Always cd into the workspace root directory
  cd ${WORKSPACE_DIR}
}

function after_test() {
  unittest_tear_down
  delete_git_cached_directory ${TEST_GIT_CACHE_DIR}
}

function test_cached_dir_created_as_expected() {
  before_test "test_cached_dir_created_as_expected"

  # Given I declare a git cache rule with custom cache directory
  commit_hash="014459e6361b66a7b210758d4bf93f3a46ca5e88"
  create_git_cached_rule_for_small_repo ${commit_hash} ${TEST_GIT_CACHE_DIR}

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_lib_ref_small_repo)

  # And I build the shell library target label
  bazel build ${target_label} >&${TEST_log} ||
    echo "Expected git cached directory to get created successfully"

  # Then I expect the repository to be cached successfully
  expect_folder ${TEST_GIT_CACHE_DIR}
  after_test
}

function test_cached_default_dir_created_as_expected() {
  before_test "test_cached_default_dir_created_as_expected"

  # Given I declare a git cache rule using the default cache directory
  commit_hash="014459e6361b66a7b210758d4bf93f3a46ca5e88"
  create_git_cached_rule_for_small_repo ${commit_hash}

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_lib_ref_small_repo)

  # And I build the shell library target label
  bazel build ${target_label} >&${TEST_log} ||
    echo "Expected git cached default directory to get created successfully"

  # Then I expect the repository to be cached successfully within default cache library
  expect_folder "$HOME/.git-cache"
  after_test
}

function test_first_checkout_is_successful() {
  before_test "test_first_checkout_is_successful"

  # Given I declare a git cache rule with custom cache directory
  commit_hash="014459e6361b66a7b210758d4bf93f3a46ca5e88"
  create_git_cached_rule_for_small_repo ${commit_hash} ${TEST_GIT_CACHE_DIR}

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # And I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to successfully fetch repo by commit hash"

  # Then I expect the binary response to return the expected static string value
  expect_log "toto, I have a feeling we are not in maven anymore"
  after_test
}

function test_checkout_post_fetch_is_successful() {
  before_test "test_checkout_post_fetch_is_successful"

  # Given I declare a git cache rule with custom cache directory
  commit_hash="014459e6361b66a7b210758d4bf93f3a46ca5e88"
  create_git_cached_rule_for_small_repo ${commit_hash} ${TEST_GIT_CACHE_DIR}

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # And I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to successfully fetch repo by commit hash"

  # Then I expect the binary response to return the expected static string value
  expect_log "toto, I have a feeling we are not in maven anymore"

  # When I create a new commit on the repository in test
  new_commit=$(create_new_commit_on_small_repo)

  # And I re-declare the git cache rule with the new commit
  recreate_git_cached_rule_for_small_repo ${new_commit} ${TEST_GIT_CACHE_DIR}

  # And I run the shell binary target label again
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to fail on 1st checkout, fetch latest changes and succeed on the 2nd checkout"

  # Then I expect to receive the updated response from the new commit
  expect_log "correct dorothy, we are in bazel world"
  after_test
}

prepare_test_repositories ${REPOS_DIR}
log_tests_suite_header "git_cached_repository should"

test_cached_default_dir_created_as_expected
test_cached_dir_created_as_expected
test_first_checkout_is_successful
test_checkout_post_fetch_is_successful
