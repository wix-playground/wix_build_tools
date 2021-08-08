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

GIT_CACHED_RULES_VERBOSE=False

function before_test() {
  unittest_set_up
  TEST_name=$1
  TEST_passed="true"
  create_clean_workspace
  define_git_rules_env_vars
  utils_log_test_name ${TEST_name}
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
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_lib_ref_small_repo)

  # When I build the shell library target label
  bazel build ${target_label} >&${TEST_log} ||
    echo "Expected git cached directory to get created successfully"

  # Then I expect the repository to be cached successfully
  assert_expect_folder ${TEST_GIT_CACHE_DIR}
  after_test
}

function test_cached_default_dir_created_as_expected() {
  before_test "test_cached_default_dir_created_as_expected"

  # Given I declare a git cache rule using the default cache directory
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_lib_ref_small_repo)

  # When I build the shell library target label
  bazel build ${target_label} >&${TEST_log} ||
    echo "Expected git cached default directory to get created successfully"

  # Then I expect the repository to be cached successfully within default cache library
  assert_expect_folder "$HOME/.git-cache"
  after_test
}

function test_first_checkout_is_successful() {
  before_test "test_first_checkout_is_successful"

  # Given I declare a git cache rule with custom cache directory
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # When I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to successfully fetch repo by commit hash"

  # Then I expect the response to return the expected static string value
  assert_expect_log "toto, I have a feeling we are not in maven anymore"
  after_test
}

function test_checkout_post_fetch_is_successful() {
  before_test "test_checkout_post_fetch_is_successful"

  # Given I declare a git cache rule with custom cache directory
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # And I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to successfully fetch repo by commit hash"

  # Then I expect the response to return the expected static string value
  assert_expect_log "toto, I have a feeling we are not in maven anymore"

  # When I create a new commit on the repository in test
  new_commit=$(create_new_commit_on_small_repo)

  # And I re-declare the git cache rule with the new commit
  recreate_git_cached_rule_for_small_repo \
    "commit = '${new_commit}'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}'"

  # When I run the shell binary target label again
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to fail on 1st checkout, fetch latest changes and succeed on the 2nd checkout"

  # Then I expect to receive the updated response from the new commit
  assert_expect_log "correct dorothy, we are in bazel world"
  after_test
}

function test_fetch_retry_count_retries_num_is_as_expected() {
  before_test "test_fetch_retry_count_retries_num_is_as_expected"

  # Given I declare a git cache rule with custom fetch retries count
  create_git_cached_rule_for_small_repo \
    "remote_url = 'https://the-road-to-nowhere.git'" \
    "commit = 'l33tf4k3c0mm1757r1n6'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}'" \
    "fetch_retries_count = 3" \
    "fetch_retry_timeout_in_sec = 2"

  # And I allow verbosity for the git cached worker
  export GIT_CACHED_VERBOSE=True

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # When I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} || true # This is negative scenario, we expect a failure

  # Then I expect to count x3 retries attempts
  assert_expect_log "Attempt #1..."
  assert_expect_log "Retry attempt #2..."
  assert_expect_log "Retry attempt #3..."

  after_test
  unset GIT_CACHED_VERBOSE
}

function test_checkout_on_cached_repo_with_index_lock_file_to_succeed() {
  before_test "test_checkout_on_cached_repo_with_index_lock_file_to_succeed"

  # Given I declare a git cache rule with custom cache directory
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}/index-locked-repo'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # And I build the shell library target label which triggers a one time fresh clone of the git repo
  bazel run ${target_label} >&${TEST_log} || echo "Expected to successfully clone repo"

  # When I create a new commit on the repository in test
  new_commit=$(create_new_commit_on_small_repo)

  # And I add an index.lock file to the cloned repo git index
  touch ${TEST_GIT_CACHE_DIR}/index-locked-repo/small_repo/.git/index.lock

  # And I re-declare the git cache rule with a new commit to trigger invalidation
  recreate_git_cached_rule_for_small_repo \
    "commit = '${new_commit}'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}/index-locked-repo'"

  # When I run the shell binary target label again
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to succeed by removing the index.lock file from the git cached folder"

  # Then I expect to receive the updated response from the new commit
  assert_expect_log "correct dorothy, we are in bazel world"
  after_test
}

function test_force_clone_when_there_is_an_invalid_remote_origin() {
  before_test "test_force_clone_when_there_is_an_invalid_remote_origin"

  # Given I create a custom cache dir with a blank git index without setting remote origin
  cached_repo_dir="${TEST_GIT_CACHE_DIR}/invalid-remote-origin"
  git_init_fresh_index "${cached_repo_dir}/small_repo"

  # And I declare a git cache rule with custom cache directory
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${cached_repo_dir}'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # And I allow verbosity for the git cached worker
  export GIT_CACHED_VERBOSE=True

  # When I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to succeed by re-creating the repository git cached folder"

  # Then I expect to identify an invalid remote origin error log
  assert_expect_log "identified an invalid remote origin url on local git index"

  # And I expect a fresh clone to succeed with logging the response value at the end of the run
  assert_expect_log "toto, I have a feeling we are not in maven anymore"
  after_test
  unset GIT_CACHED_VERBOSE
}

# Examples for invalid git index:
#   - fatal: your current branch 'master' does not have any commits yet
#     This error can trigger after a user is aborting the build process after git init of a cached repo
function test_force_clone_when_git_index_is_invalid() {
  before_test "test_force_clone_when_git_index_is_invalid"

  # Given I create a custom cache dir with a blank git index using only git init
  cached_repo_dir="${TEST_GIT_CACHE_DIR}/invalid-index-repo"
  git_init_fresh_index "${cached_repo_dir}/small_repo"

  # And I set small_repo repo path as the remote origin
  git_remote_add_origin "${cached_repo_dir}/small_repo" "${REPO_SMALL_DIR}"

  # And I declare a git cache rule with custom cache directory and remote_url
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${cached_repo_dir}'" \
    "remote_url = '${REPO_SMALL_DIR}'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_binary_ref_small_repo)

  # And I allow verbosity for the git cached worker
  export GIT_CACHED_VERBOSE=True

  # When I run the shell binary target label
  bazel run ${target_label} >&${TEST_log} ||
    echo "Expected to succeed by re-creating the repository git cached folder"

  # Then I expect to identify an invalid git index error log
  assert_expect_log "identified an invalid local git index"

  # And I expect a fresh clone to succeed with logging the response value at the end of the run
  assert_expect_log "toto, I have a feeling we are not in maven anymore"
  after_test
  unset GIT_CACHED_VERBOSE
}

function test_git_version_log_when_debug_enabled() {
  before_test "test_git_version_log_when_debug_enabled"

  # Given I declare a git cache rule with custom cache directory
  create_git_cached_rule_for_small_repo \
    "commit = '014459e6361b66a7b210758d4bf93f3a46ca5e88'" \
    "cache_directory = '${TEST_GIT_CACHE_DIR}'"

  # And I create a shell library to reference the git cache rule
  target_label=$(create_sh_lib_ref_small_repo)

  # And I allow log verbosity
  export GIT_CACHED_VERBOSE=True

  # When I build the shell library target label
  bazel build ${target_label} >&${TEST_log} ||
    echo "Expected git cached directory to get created successfully"

  # Then I expect the repository to be cached successfully
  assert_expect_log "git version"
  after_test
  unset GIT_CACHED_VERBOSE
}

prepare_test_repositories ${REPOS_DIR}
utils_log_tests_suite_header "git_cached_repository should"

test_cached_default_dir_created_as_expected
test_cached_dir_created_as_expected
test_first_checkout_is_successful
test_checkout_post_fetch_is_successful
test_fetch_retry_count_retries_num_is_as_expected
test_checkout_on_cached_repo_with_index_lock_file_to_succeed
test_force_clone_when_there_is_an_invalid_remote_origin
test_force_clone_when_git_index_is_invalid
test_git_version_log_when_debug_enabled