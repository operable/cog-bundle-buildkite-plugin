#!/bin/bash

set -eu

# We have to use cat because pipeline.yml $ interpolation doesn't work in YAML
# keys, only values
cat <<YAML
steps:

  - label: ":shell: Linting"
    plugins:
      operable/shellcheck:
        script:
          - hooks/command
          - hooks/commands/build.sh
          - hooks/commands/test.sh
          - hooks/common.sh
          - hooks/post-command
          - scripts/run
        opts: -x

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


for cog in master
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
