#!/bin/bash

set -euo pipefail

# Kind of a pain to require BUILDKITE_PLUGIN_COG_BUNDLE_BUILD all the
# time, this since it's gonna be `config.yaml` pretty much always

if [[ ! -z "${BUILDKITE_PLUGIN_COG_BUNDLE_TAG:-}" ]]
then
    # Use the user-specified tag
    BUNDLE_IMAGE=${BUILDKITE_PLUGIN_COG_BUNDLE_TAG}
else
    # Pull out image information from config file and add some build
    # metadata to the tag
    # shellcheck disable=2046
    eval $(docker run --rm -i operable/ruby:2.3.1-r0 ruby -ryaml -rjson \
                  -e "puts JSON.dump(YAML.load(ARGF.read))" < "${BUILDKITE_PLUGIN_COG_BUNDLE_BUILD}" \
                  | jq -r '@sh "IMAGE=\(.docker.image) TAG=\(.docker.tag)"')
    BUNDLE_IMAGE="${IMAGE}:${TAG}-${BUILDKITE_BUILD_NUMBER}-${BUILDKITE_COMMIT}"
fi

DOCKERFILE=${BUILDKITE_PLUGIN_COG_BUNDLE_DOCKERFILE:-Dockerfile}
CONTEXT="$(cd "$( dirname "${DOCKERFILE}}" )" && pwd)"

echo "--- :docker: Building bundle image ${BUNDLE_IMAGE}"
plugin_prompt_and_run docker build -t "${BUNDLE_IMAGE}" -f "${CONTEXT}"/"$(basename "${DOCKERFILE}")" "${CONTEXT}"

if [ -z "${BUILDKITE_PLUGIN_COG_BUNDLE_PUSH+x}" ] || [ "true" == "${BUILDKITE_PLUGIN_COG_BUNDLE_PUSH}" ]
then
    # Either push isn't specified, in which case we default to
    # pushing, or it is specified, and it's true
    echo "--- :docker: Pushing bundle image ${BUNDLE_IMAGE}"
    plugin_prompt_and_run docker push "${BUNDLE_IMAGE}"
fi

echo "--- :buildkite: Adding ${BUNDLE_IMAGE} to meta-data"
plugin_prompt_and_run buildkite-agent meta-data set "operable-bundle-testing-image" "${BUNDLE_IMAGE}"
