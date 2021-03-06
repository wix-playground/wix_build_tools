<h1>Wix build rules and macros for Bazel</h1>

<h3 id="wix-logo">
	<img src="assets/icons/bazel.svg" height="80" width="80">BUILD 
	<img src="assets/icons/wix.svg" height="80" width="140"> EXTEND
</h3>

<br>

A place for rules and macros that were built inside [Wix](https://www.wix.engineering/).

[![Build status](https://github.com/wix-playground/wix_build_tools/actions/workflows/continuous-integration-workflow.yml/badge.svg)](https://github.com/wix-playground/wix_build_tools/actions/workflows/continuous-integration-workflow.yml)

<br>

- [Overview](#overview)
- [Getting Started](#getting-started)
- [Rules](#rules)
   - [git_cached_repository](#git_cached_repository)
      - [Usage](#git_cached_repository_usage)
      - [Attributes](#git_cached_repository_attr)
- [Contributing Guidelines](#contributing)
- [FAQ](#faq)

<br>

<h2 id="overview">Overview</h2>

This repository currently contains the `git_cached_repository` rule. Please note that this is still in alpha phase. Feel free to try it out but be aware that there may still be uncovered cases, and that the API might change.

| :heavy_exclamation_mark: Preliminary Steps |
| :--------------------------------------- |
| Before starting, make sure you have Bazel [properly installed](https://docs.bazel.build/install.html) and are familiar with the Bazel [getting started](https://docs.bazel.build/getting-started.html) guide. |

<br>

<h2 id="getting-started">Getting Started</h2>

1. Add the following to your `WORKSPACE` file to reference this external repository:

   ```python
   wix_build_tools_version="f9b27a7c3fc30532d9bab2b8e2ca3f9f3d1f83b9"
   wix_build_tools_version_sha256="4c45cb488126aaba5218edeaecec1dac448a9c93b1010423d65b82b039713d69"
   http_archive(
       name = "wix_build_tools",
       urls = ["https://github.com/wix-playground/wix_build_tools/archive/%s.zip" % wix_build_tools_version],
       strip_prefix = "wix_build_tools-%s" % wix_build_tools_version,
       sha256 = wix_build_tools_version_sha256,
   )
   ```

1. Load the repository rule in any `*.bzl` file you wish to use `git_cached_repository`:

   ```python
   load("@wix_build_tools//git:git_cached_repository.bzl", "git_cached_repository")
   ```

1. **(Optional):** Calculate SHA256 for a specific commit (copy & paste into your terminal):

   ```bash
   bash <<'EOF'
   
   REVISION=f9b27a7c3fc30532d9bab2b8e2ca3f9f3d1f83b9
   
   repo_path=$(mktemp -d ${TMPDIR:-/tmp}/wix_build_tools-shasum.XXXXXX)
   cwd=$(pwd)
   cd ${repo_path}
   curl -s https://github.com/wix-playground/wix_build_tools/archive/"${REVISION}".zip \
        -L -o wix_build_tools_${REVISION}.zip
   
   echo "SHA 256:"
   shasum -a 256 ${repo_path}/wix_build_tools_${REVISION}.zip
   cd ${cwd}
   
   EOF
   ```

<br>

<h2 id="rules">Rules</h2>

<h3 id="git_cached_repository">git_cached_repository</h3>

Rule for caching external git repositories in favor of keeping a lighter git network overhead.
Utilizing the [`GIT_DIR`](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables) environment variable, it maintains a shared git index across all local workspaces (defaults to `$HOME/.git-cache`).
In case a revision is not available, a git fetch takes place to retrieve the deltas and then perform another checkout.
In order to lower index size, `HEAD` references are being fetched from `master` branch (_configurable_) and using `shallow_since` to limit history and stale content (_configurable as well_).

| :heavy_exclamation_mark: WARNING |
| :--------------------------------------- |
| This repository rule is still in **alpha stage**, use it with caution !<br>Please open a GitHub Issue/PR for any potential issues you might encounter. |

<h4 id="git_cached_repository_usage">Usage</h4>

Add the following declaration to any `*.bzl` file to cache an external git repository:

```python
git_cached_repository(
    name = "my-super-repository",
    remote_url = "https://github.com/<organization-name>/<repository-name>.git",
    commit = "repository-revision",
    shallow_since = "4 weeks ago",
)
```

<h4 id="git_cached_repository_attr">Attributes</h4>

| **Name**            | **Type**           | **Default value**
| :---                           | :---                        | :---
| `name`       | `string`    | **mandatory**
| A unique name for the library
| `remote_url` | `string`    | **mandatory**
| The URI of the remote Git repository
| `commit`     | `string`    | **mandatory**
| Specific commit to get checked out
| `branch`     | `string`    | master
| Specify a branch to fetch HEAD references
| `shallow_since`     |  `string`  | none
| An optional date in addition to a specified commit.<br>Setting such a date close to the specified commit allows for a more shallow clone <br>of the repository, saving bandwidth
| `cache_directory`     | `string`    | none
| Local path to clone the repository into.<br>Default location is used to clone into `$HOME/.git-cache/<repo-name>`
| `fetch_retries_count`     | `int`    | 2
| Amount of retries attempts for fetching a repository before failing
| `fetch_retry_timeout_in_sec`     | `int`    | 300 sec
| Time to wait for a single fetch retry attempt

<br>

<h2 id="contributing">Contributing Guidelines</h2>

- PRs need to have a clear description of the problem they are solving
- PRs should be small
- Code without tests is not accepted
- Contributions must not add additional dependencies
- Before creating a PR, make sure your code is well formatted, abstractions are named properly and design is simple
- In case your contribution can't comply with any of the above please start a GitHub issue for discussion

<br>

<h2 id="faq">FAQ</h2>

Help !
