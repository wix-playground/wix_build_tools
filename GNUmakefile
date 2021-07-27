default: help

.PHONY: run-tests-ci
run-tests-ci: ## Run tests suites on CI containerized environment
	./testing/git_cached_repository/git_cached_repository.sh

.PHONY: run-tests-dockerized
run-tests-dockerized: ## Run tests suites dockerized
	docker run -it \
        -v $(PWD):/home/wix_build_tools \
        --entrypoint /bin/sh l.gcr.io/google/bazel:3.5.0 \
        -c 'cd /home/wix_build_tools; make run-tests-ci'

# To use on version 3.0.0 of Docker for mac - disable use gRPC FUSE for file sharing in Preferences -> Experimental Features.
# Debug within the container by using: (run from wix_build_tools root folder)
#  - docker run -it -v $(PWD):/home/wix_build_tools --entrypoint /bin/sh l.gcr.io/google/bazel:3.5.0

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

