"""Code for interacting with git binary to get the file tree checked out at the specified revision.
"""

_env_var_enable_verbosity = "GIT_CACHED_VERBOSE"

_GitRepoInfo = provider(
    doc="Provider to organize precomputed arguments for calling git.",
    fields={
        "cache_dir":
            "Repository cached directory path",
        "remote_url":
            "URL of the git repository to fetch from",
        "commit":
            "Specific commit to be checked out",
        "branch":
            "Specify a branch to fetch HEAD references",
        "shallow_since":
            "Actual date and time of the commit of the checked out data.",
        "update_shallow":
            "Accept refs that require updating .git/shallow",
    },
)

_RuleExecInfo = provider(
    doc="Provider to organize rule execution behavior.",
    fields={
        "fetch_retries_count":
            "Amount of retries attempts for fetching a repository before failing",
        "fetch_retry_timeout_in_sec":
            "Time to wait for a single fetch retry attempt",
    },
)


def checkout(ctx, cache_dir):
    """ Reset to a specific commit-hash. Do not fail if commit-hash could not be found, rather return a managed response
        indicating a failure since a fetch might be required if repository state is behind

        Args:
            ctx: Repository context of the calling rule
            cache_dir: Cache destination to host the .git directory of this specific repository

        Returns:
            Actual commit hash and date of the git clone state
    """
    git_repo_info = _create_git_repo_info(ctx, cache_dir)

    _log(ctx,
         "Checking out by commit hash. name: {}, value: {}".format(
             ctx.name, ctx.attr.commit))

    # Fail gracefully
    result = _reset(ctx, git_repo_info)
    if result.success == False:
        _log(
            ctx, "Failed to reset commit hash. name: {}, value: {}".format(
                ctx.name, ctx.attr.commit))
        return _empty_git_worker_response()
    else:
        _log(
            ctx, "Successfully reset commit hash. name: {}, value: {}".format(
                ctx.name, ctx.attr.commit))
        return _prepare_git_worker_response(ctx, git_repo_info)


def fetch(ctx, cache_dir, should_update_shallow=False):
    """ Fetch all commits references (a.k.a refs/commit-hash alias) which means all branches and tags
        to get all recent changes made to certain repository. Clean untracked files upon completion

        Args:
            ctx: Repository context of the calling rule
            cache_dir: Cache destination to host the .git directory of this specific repository
            should_update_shallow: Accept refs that require updating .git/shallow

        Returns:
            Actual commit hash and date of the git clone state
    """
    git_repo_info = _create_git_repo_info(
        ctx, cache_dir, should_update_shallow=should_update_shallow)
    rule_exec_info = _create_rule_exec_info(ctx)

    _log(
        ctx, "Fetching repository from branch. name: {}, flags: {}".format(
            ctx.name, git_repo_info.shallow_since))

    _fetch(ctx, git_repo_info, rule_exec_info)
    _clean(ctx, git_repo_info)

    return _prepare_git_worker_response(ctx, git_repo_info)


def clone(ctx, cache_dir):
    """ Initialize a git repository into a dedicated cache folder while cloning into a different working directory
        which is the external Bazel folder. Clean untracked files upon completion

        Args:
            ctx: Repository context of the calling rule
            cache_dir: Cache destination to host the .git directory of this specific repository

        Returns:
            Actual commit hash and date of the git clone state
    """
    git_repo_info = _create_git_repo_info(ctx, cache_dir)
    rule_exec_info = _create_rule_exec_info(ctx)

    _log(
        ctx, "Cloning repository. name: {}, path: {}, flags: {}".format(
            ctx.name, cache_dir, git_repo_info.shallow_since))

    _init(ctx, git_repo_info)
    _add_origin(ctx, git_repo_info)
    _fetch(ctx, git_repo_info, rule_exec_info)

    result = _reset(ctx, git_repo_info)
    if result.success == False:
        fail("Resetting to commit hash failed. error: {}".format(
            result.message))

    _clean(ctx, git_repo_info)

    return _prepare_git_worker_response(ctx, git_repo_info)


def _is_verbosity_enabled(ctx):
    return ctx.os.environ.get(_env_var_enable_verbosity, "") == "True"


def _log(ctx, message, report_progress=False):
    if report_progress:
        ctx.report_progress(message)

    if _is_verbosity_enabled(ctx):
        print(message)


def _create_git_repo_info(ctx, cache_dir, should_update_shallow=False):
    return _GitRepoInfo(
        cache_dir=str(ctx.path(cache_dir)),
        remote_url=str(ctx.attr.remote_url),
        commit=ctx.attr.commit,
        branch=ctx.attr.branch,
        shallow_since=_get_shallow_since(ctx),
        update_shallow=_get_update_shallow(should_update_shallow),
    )


def _create_rule_exec_info(ctx):
    return _RuleExecInfo(
        fetch_retries_count=ctx.attr.fetch_retries_count,
        fetch_retry_timeout_in_sec=ctx.attr.fetch_retry_timeout_in_sec,
    )


def _get_shallow_since(ctx):
    return ("--shallow-since=%s" %
            ctx.attr.shallow_since) if ctx.attr.shallow_since else ""


def _get_update_shallow(update_shallow):
    return "--update-shallow" if update_shallow else ""


def _init(ctx, git_repo_info):
    cl = ["git", "init"]
    exec_result = ctx.execute(
        cl,
        environment=ctx.os.environ,
        working_directory=git_repo_info.cache_dir,
    )
    if exec_result.return_code != 0:
        _error(ctx.name, cl, exec_result.stderr)


def _add_origin(ctx, git_repo_info):
    """ Add remote origin and suppress error if remote origin already exists

        Args:
            ctx: Repository context of the calling rule
            git_repo_info: Precomputed arguments for calling git

        Returns:
            Actual commit hash and date of the git clone state
    """
    _git(ctx, git_repo_info, "remote", "add", "origin",
         git_repo_info.remote_url)


def _fetch(ctx, git_repo_info, rule_exec_info):
    # We need to explicitly specify to fetch all branches and tags, otherwise only
    # HEAD-reachable is fetched.
    # The arguments below work correctly for both before 1.9 and after 1.9,
    # as we directly specify the list of references to fetch.
    _log(
        ctx,
        "About to fetch {} with {} retries and {} second(s) timeout per retry".
        format(
            git_repo_info.remote_url,
            rule_exec_info.fetch_retries_count,
            rule_exec_info.fetch_retry_timeout_in_sec,
        ))

    _git_maybe_shallow(
        ctx,
        git_repo_info,
        "fetch",
        rule_exec_info.fetch_retries_count,
        rule_exec_info.fetch_retry_timeout_in_sec,
        "--force",
        "origin",
        "refs/heads/{}:refs/remotes/origin/{}".format(git_repo_info.branch, git_repo_info.branch),
    )


def _reset(ctx, git_repo_info):
    return _git_fail_gracefully(ctx, git_repo_info, "reset", "--hard",
                                git_repo_info.commit)


def _clean(ctx, git_repo_info):
    _git(ctx, git_repo_info, "clean", "-xdf")


def _get_head_commit(ctx, git_repo_info):
    return _git(ctx, git_repo_info, "log", "-n", "1", "--pretty=format:%H")


def _get_head_date(ctx, git_repo_info):
    return _git(ctx, git_repo_info, "log", "-n", "1", "--pretty=format:%cd",
                "--date=raw")


def _git_maybe_shallow(ctx,
                       git_repo_info,
                       command,
                       retry_count=1,
                       retry_timeout_in_sec=600,
                       *args):
    start = ["git", command]
    args_list = list(args)

    if git_repo_info.update_shallow:
        exec_result = _execute_with_retry(
            ctx,
            git_repo_info,
            start + [git_repo_info.update_shallow] + args_list,
            retry_count,
            retry_timeout_in_sec,
        )

        if exec_result.return_code == 0:
            return

    if git_repo_info.shallow_since:
        exec_result = _execute_with_retry(
            ctx,
            git_repo_info,
            start + [git_repo_info.shallow_since] + args_list,
            retry_count,
            retry_timeout_in_sec,
        )

        if exec_result.return_code == 0:
            return

    exec_result = _execute_with_retry(
        ctx,
        git_repo_info,
        start + args_list,
        retry_count,
        retry_timeout_in_sec,
    )

    if exec_result.return_code != 0:
        _error(ctx.name, start + args_list, exec_result.stderr)


def _git(ctx, git_repo_info, command, *args):
    start = ["git", command]
    args_list = list(args)
    exec_result = _execute(ctx, git_repo_info, start + args_list)
    if exec_result.return_code != 0:
        _error(ctx.name, start + args_list, exec_result.stderr)
    return exec_result.stdout


def _git_fail_gracefully(ctx, git_repo_info, command, *args):
    start = ["git", command]
    exec_result = _execute(ctx, git_repo_info, start + list(args))
    if exec_result.return_code != 0:
        return struct(message=exec_result.stderr, success=False)
    return struct(message=exec_result.stdout, success=True)


def _execute(ctx, git_repo_info, args):
    _log(ctx, "git args: " + str(args))
    working_dir = str(ctx.path("."))
    return ctx.execute(
        args,
        environment=_define_git_dir_env_var(ctx, git_repo_info),
        working_directory=working_dir,
    )


def _execute_with_retry(ctx,
                        git_repo_info,
                        args,
                        retry_count=1,
                        retry_timeout_in_sec=600):
    _log(ctx, "git args (with retry): " + str(args))
    working_dir = str(ctx.path("."))
    result = None
    for counter in range(retry_count):
        _log(ctx, ("Attempt #{}..." if counter == 0 else
                   "Retry attempt #{}...").format(counter + 1))
        result = ctx.execute(
            args,
            timeout=retry_timeout_in_sec,
            environment=_define_git_dir_env_var(ctx, git_repo_info),
            working_directory=working_dir,
        )

        if result.return_code == 0:
            return result

    return result


def _error(name, command, stderr):
    command_text = " ".join([str(item).strip() for item in command])
    fail("error running '%s' while working with @%s:\n%s" %
         (command_text, name, stderr))


def _define_git_dir_env_var(ctx, git_repo_info):
    git_dir_path = git_repo_info.cache_dir + "/.git"
    env_vars = dict(ctx.os.environ)
    env_vars.update({"GIT_DIR": git_dir_path})
    return env_vars


def _prepare_git_worker_response(ctx, git_repo_info):
    actual_commit = _get_head_commit(ctx, git_repo_info)
    shallow_date = _get_head_date(ctx, git_repo_info)
    return struct(actual_commit=actual_commit, shallow_date=shallow_date)


def _empty_git_worker_response():
    return struct(actual_commit=None, shallow_date=None)