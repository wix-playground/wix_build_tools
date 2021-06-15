#!/bin/bash

# Title        repos_loader.sh
# Description  Load all mocked git repositories making their "local remote_url" available via env vars
#=====================================================================================================

source ./testing/e2e/logging.sh

REPOS_DIR=""
REPO_SMALL_DIR=""

function prepare_test_repositories() {
  REPOS_DIR=${TEST_TMPDIR}/repos
  if [ -e "${REPOS_DIR}" ]; then
    rm -rf ${REPOS_DIR}
  fi

  if [[ -d ${REPOS_DIR} ]]; then
    log_info "Repositories folder is already initialized, skipping"
  fi

  mkdir -p $REPOS_DIR

  cp ./testing/testdata/small-repo.tar.gz $REPOS_DIR

  cwd=$(pwd)
  cd $REPOS_DIR
  tar zxf small-repo.tar.gz
  cd $cwd

  assign_repos_paths
}

function assign_repos_paths() {
  #
  # -=-=-=-== GIT LOG STRUCTURE OF THE SMALL-REPO REPOSITORY =-=-=-=-=-
  #
  # commit 014459e6361b66a7b210758d4bf93f3a46ca5e88 (HEAD -> master)
  # Author: Zachi Nachshon <zachin@wix.com>
  # Date:   Sun Apr 25 16:38:18 2021 +0300
  #
  #     Added filegroup for all movie quotes
  #
  # commit 92bc367aca2c9938429477988da4619624d30797
  # Author: Zachi Nachshon <zachin@wix.com>
  # Date:   Sun Apr 25 16:37:59 2021 +0300
  #
  #     Added quote: the wizard of oz
  #
  # commit 40cbd41404e706e364a857df366fff31431149bf
  # Author: Zachi Nachshon <zachin@wix.com>
  # Date:   Sun Apr 25 16:37:44 2021 +0300
  #
  #     Added quote: jerry maguire
  #
  # commit 7dc71f1c24115ef7fa598ce98e081b7c14d7bae7
  # Author: Zachi Nachshon <zachin@wix.com>
  # Date:   Sun Apr 25 16:37:27 2021 +0300
  #
  #     Added quote: field of dreams
  #
  # commit 5f1c1939fe16bd29280a8e2df2ed5eb67528abb4
  # Author: Zachi Nachshon <zachin@wix.com>

  # $WORKSPACE_DIR/
  #   .git
  #   BUILD
  #   WORKSPACE
  #   quotes/
  #     BUILD
  #     field_of_dreams.txt
  #     jerry_maguire.txt
  #     the_wizard_of_oz.txt
  REPO_SMALL_DIR=${REPOS_DIR}/small-repo
}
