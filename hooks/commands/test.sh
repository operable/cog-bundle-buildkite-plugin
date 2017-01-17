#!/bin/bash

set -euo pipefail

dir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
plugin_root="$(cd ${dir}/../.. && pwd)"

TESTING_IMAGE=$(buildkite-agent meta-data get "operable-bundle-testing-image")

# Can be tag, branch, or (complete) SHA
COG_VERSION=${BUILDKITE_PLUGIN_COG_BUNDLE_COG_VERSION:-master}
export COG_HOST=$(ifconfig ${INTERFACE:-eth0} | grep -Eo "inet (addr:)?([0-9]*\.){3}[0-9]*" | grep -Eo "([0-9]*\.){3}[0-9]*")
export COG_PORT=4000

random_password() {
    openssl rand -base64 32
}

export COG_BOOTSTRAP_USERNAME=admin
export COG_BOOTSTRAP_PASSWORD=$(random_password)

echo "--- :github: Fetching docker-compose files for Cog@${COG_VERSION}"
url_base="https://raw.githubusercontent.com/operable/cog/${COG_VERSION}"
for compose_file in docker-compose.yml docker-compose.common.yml
do
    plugin_prompt_and_run curl --silent --show-error --fail --remote-name "${url_base}/${compose_file}"
    cat ${compose_file}
done

INTEGRATION_MANIFEST=${BUILDKITE_PLUGIN_COG_BUNDLE_TEST}
BUNDLE_CONFIG=${BUILDKITE_PLUGIN_COG_BUNDLE_CONFIG:-config.yaml}

cat > docker-compose.override.yml <<YAML
version: '2'
services:
  cog:
    environment:
      - SLACK_API_TOKEN=${SLACK_API_TOKEN}
      - COG_SLACK_ENABLED=1
      - COG_BOOTSTRAP_USERNAME=${COG_BOOTSTRAP_USERNAME}
      - COG_BOOTSTRAP_PASSWORD=${COG_BOOTSTRAP_PASSWORD}
      - COG_BOOTSTRAP_EMAIL_ADDRESS=cog@localhost
      - COG_BOOTSTRAP_FIRST_NAME=Cog
      - COG_BOOTSTRAP_LAST_NAME=Administrator
      - COG_TELEMETRY=false
      - RELAY_ID=00000000-0000-0000-0000-000000000000
      - RELAY_COG_TOKEN=supersecret

  relay:
    environment:
      - RELAY_ID=00000000-0000-0000-0000-000000000000
      - RELAY_COG_TOKEN=supersecret
      - RELAY_MANAGED_DYNAMIC_CONFIG=1
      - RELAY_DYNAMIC_CONFIG_ROOT=/tmp/relay_config
      - RELAY_LOG_LEVEL=debug
      - RELAY_COG_REFRESH_INTERVAL=1s

  integration:
    build:
      context: ${plugin_root}
    entrypoint: [ run ]
    volumes:
      - ./cogctl:/root/.cogctl
      - ./${BUNDLE_CONFIG}:/config.yaml
      - ./${INTEGRATION_MANIFEST}/:/integration.yaml
    environment:
      - COG_INTEGRATION_USERNAME=${COG_BOOTSTRAP_USERNAME}
      - COG_INTEGRATION_PASSWORD=${COG_BOOTSTRAP_PASSWORD}
      - COG_PORT=${COG_PORT}
      - TESTING_IMAGE=${TESTING_IMAGE}
    depends_on:
      - cog
      - relay
YAML

plugin_prompt_and_run cat docker-compose.override.yml

cat > cogctl <<COGCTL
[defaults]
profile=cog
[cog]
host=cog
password=${COG_BOOTSTRAP_PASSWORD}
port=${COG_PORT}
secure=false
user=${COG_BOOTSTRAP_USERNAME}
COGCTL

plugin_prompt_and_run cat cogctl

retrieve_logs() {

    set +e
    echo

    echo "--- :cogops: :memo: Cog logs"
    run_docker_compose logs cog

    echo "--- :cogops: :memo: Cog event logs"
    run_docker_compose exec cog cat data/audit_logs/events.log

    echo "--- :cogops: :memo: Relay logs"
    run_docker_compose logs relay

    set -e
}

trap retrieve_logs EXIT

# Set it all up
echo "--- :docker: :hammer_and_wrench: Building Container"
run_docker_compose build integration

echo "--- :docker: :running: Running Bundle Integration Tests in Container"
run_docker_compose run integration
