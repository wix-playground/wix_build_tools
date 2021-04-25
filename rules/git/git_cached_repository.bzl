load("//rules/git:git_cached_worker.bzl", "checkout", "clone", "fetch")

"""Rules for caching external git repositories in favor of keeping a lighter git network overhead."""

load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "patch",
    "update_attrs",
    "workspace_and_buildfile",
)

_env_var_enable_verbosity = "GIT_CACHED_VERBOSE"

_common_attrs = {
    "remote_url": attr.string(
        mandatory = True,
        doc = "The URI of the remote Git repository",
    ),
    "commit": attr.string(
        mandatory = True,
        doc = "Specific commit to be checked out",
    ),
    "branch": attr.string(
        default = "master",
        doc = "Specify a branch to fetch HEAD references",
    ),
    "shallow_since": attr.string(
        default = "",
        doc = "An optional date in addition to a specified commit. " +
              "Setting such a date close to the " +
              "specified commit allows for a more shallow clone of the " +
              "repository, saving bandwidth and wall-clock time.",
    ),
    "cache_directory": attr.string(
        doc = "Local path to clone the repository into, " +
              "a default location can be used to clone into $HOME/.git-cache/<repo-name>",
    ),
    "fetch_retries_count": attr.int(
        default = 2,
        doc =
            "Amount of retries attempts for fetching a repository before failing",
    ),
    "fetch_retry_timeout_in_sec": attr.int(
        default = 300,
        doc = "Time to wait for a single fetch retry attempt",
    ),
}

def _is_verbosity_enabled(repo_ctx):
    return repo_ctx.os.environ.get(_env_var_enable_verbosity, "") == "True"

def _log(repo_ctx, message, report_progress = False):
    if report_progress:
        repo_ctx.report_progress(message)

    if _is_verbosity_enabled(repo_ctx):
        print(message)

def _get_local_cache_repo_path(repo_ctx):
    """ Return a default local path to clone the repository into else return the cache_directory attribute if supplied
        (default location: $HOME/.git-cache/<repo-name>)

        Args:
            repo_ctx: Repository context of the calling rule

        Returns:
            Path to the local repository cache folder
    """
    if not repo_ctx.attr.cache_directory:
        home = repo_ctx.os.environ["HOME"]
        return "{}/.git-cache/{}".format(home, repo_ctx.name)

    return "{}/{}".format(repo_ctx.attr.cache_directory, repo_ctx.name)

def _should_clone_repo(repo_ctx, repo_local_cache_path):
    """ Checks if a repository clone exists locally by verifying it has the .git folder path on local cache
        and that remote url is as specified on the rules attributes

        Args:
            repo_ctx: Repository context of the calling rule
            repo_local_cache_path: Path of the repository cache folder

        Returns:
            Indicator if the repository should get cloned locally
    """
    if not repo_ctx.path(repo_local_cache_path + "/.git").exists:
        return True
    else:
        args = [
            "git",
            "-C",
            repo_local_cache_path,
            "remote",
            "get-url",
            "origin",
        ]
        st = repo_ctx.execute(args, quiet = False)
        if st.return_code == 0:
            stripped_url = st.stdout.strip().replace("\n", "")

            # In case remote url differ, a clone is required
            return not stripped_url == repo_ctx.attr.remote_url
        else:
            fail(
                "Failed to verify local git repository cached folder. name: {}, error: {}"
                    .format(repo_ctx.name, st.stderr),
            )

def _create_local_cache_folder_for_repo(repo_ctx, repo_local_cache_path):
    """ Create a local folder, clear previous one if existed before

        Args:
            repo_ctx: Repository context of the calling rule
            repo_local_cache_path: Path where to create the repository cache folder
    """
    if repo_local_cache_path.endswith(repo_ctx.name):
        args = ["rm", "-r", repo_local_cache_path]
        repo_ctx.execute(args, quiet = True)

    args = ["mkdir", "-p", repo_local_cache_path]
    repo_ctx.execute(args, quiet = False)

def _fresh_clone(repo_ctx, repo_local_cache_path):
    """ Clone a repository to a folder specified by the 'repo_local_cache_path' argument,
        clear previous directory if existed before

        Args:
            repo_ctx: Repository context of the calling rule
            repo_local_cache_path: Path where to clone the repository

        Returns:
            Git worker result after a repository clone
    """
    _create_local_cache_folder_for_repo(repo_ctx, repo_local_cache_path)
    cache_dir = str(repo_local_cache_path)

    _log(
        repo_ctx,
        "Performing one time fresh clone. This may take a while...",
        report_progress = True,
    )
    clone(repo_ctx, cache_dir)

def _checkout_or_fetch(repo_ctx, repo_local_cache_path):
    """ Check out a repository by commit hash or fetch if commit hash is ahead and try to checkout again afterwards

        Args:
            repo_ctx: Repository context of the calling rule
            repo_local_cache_path: Path of the repository cache folder

        Returns:
            Git worker response
    """
    _log(
        repo_ctx,
        "Trying to checkout code at commit {}".format(repo_ctx.attr.commit),
        report_progress = True,
    )
    git_result = checkout(repo_ctx, repo_local_cache_path)

    # In case checkout failed, we'll fetch and then checkout again
    if git_result.actual_commit == None:
        _log(
            repo_ctx,
            "Performing git fetch of recent commits... (after 1st checkout attempt)",
            report_progress = True,
        )

        fetch(repo_ctx, repo_local_cache_path)
        _log(
            repo_ctx,
            "Trying to checkout code at commit {}".format(
                repo_ctx.attr.commit,
            ),
            report_progress = True,
        )
        git_result = checkout(repo_ctx, repo_local_cache_path)
        if git_result.actual_commit == None:
            _log(
                repo_ctx,
                "Performing update_shallow and fetch again... (after 2nd checkout attempt)",
                report_progress = True,
            )

            # TODO: If update_shallow won't cut it, we might require to perform checkout by date, is it possible ??
            fetch(repo_ctx, repo_local_cache_path, should_update_shallow = True)

            _log(
                repo_ctx,
                "Trying to checkout code at commit {}".format(
                    repo_ctx.attr.commit,
                ),
                report_progress = True,
            )
            git_result = checkout(repo_ctx, repo_local_cache_path)

            if git_result.actual_commit == None:
                fail(
                    "Failed to fetch from remote repository. remote: {}, commit: {}"
                        .format(
                        repo_ctx.attr.remote_url,
                        repo_ctx.attr.commit,
                    ),
                )

def _git_cached_repository_implementation(repo_ctx):
    _log(
        repo_ctx,
        "Retrieving external sources at commit {}".format(
            repo_ctx.attr.commit,
        ),
        report_progress = True,
    )

    repo_local_cache_path = _get_local_cache_repo_path(repo_ctx)
    if _should_clone_repo(repo_ctx, repo_local_cache_path):
        _fresh_clone(repo_ctx, repo_local_cache_path)
    else:
        _checkout_or_fetch(repo_ctx, repo_local_cache_path)

git_cached_repository = repository_rule(
    implementation = _git_cached_repository_implementation,
    attrs = _common_attrs,
    doc = """Clone an external Wix git repository.
Clones a Git repository, checks out by commit-hash,
and makes its targets available for binding.
""",
)
