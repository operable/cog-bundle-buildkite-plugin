#!/bin/bash

set -eu

# We have to use cat because pipeline.yml $ interpolation doesn't work in YAML
# keys, only values
cat <<YAML
steps:

  - command: .buildkite/scripts/shellcheck.sh -x hooks/command
    label: ":shell: :white_check_mark: Linting the Shell Scripts"

  - wait

  - label: Build a Cog Bundle Image
    plugins:
      operable/cog-bundle#${BUILDKITE_COMMIT}:
        build: test/config.yaml
        dockerfile: test/Dockerfile

  - label: Build a Cog Bundle Image with custom tag
    plugins:
      operable/cog-bundle#${BUILDKITE_COMMIT}:
        build: test/config.yaml
        dockerfile: test/Dockerfile
        tag: cogcmd/format-testing:even-more-testing-${BUILDKITE_BUILD_NUMBER}

  - label: Build image, but don't push
    plugins:
      operable/cog-bundle#${BUILDKITE_COMMIT}:
        build: test/config.yaml
        dockerfile: test/Dockerfile
        tag: foo/bar:1.0.0
        push: "false" # TODO: Shouldn't need to be quoted

  - wait
YAML


for cog in cm/docker-compose-v2
do
cat <<STEP
  - label: ":cogops: cog@${cog}"
    plugins:
      operable/cog-bundle#${BUILDKITE_COMMIT}:
        test: test/integration.yaml
        cog-version: ${cog}
        config: test/config.yaml
STEP
done
