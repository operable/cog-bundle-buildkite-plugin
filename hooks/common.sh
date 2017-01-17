#!/bin/bash

set -euo pipefail

# Stolen from Buildkite's docker-compose plugin

# Show a prompt for a command
function plugin_prompt {
  # Output "$" prefix in a pleasant grey...
  echo -ne "\033[90m$\033[0m"

  # ...each positional parameter with spaces and correct escaping for copy/pasting...
  printf " %q" "$@"

  # ...and a trailing newline.
  echo
}

# Shows the command being run, and runs it
function plugin_prompt_and_run {
  plugin_prompt "$@"
  "$@"
}

# Returns the name of the docker compose project for this build
function docker_compose_project_name() {
  # No dashes or underscores because docker-compose will remove them anyways
  echo "buildkite${BUILDKITE_JOB_ID//-}"
}

function run_docker_compose() {
    local command=(docker-compose)
    command+=(-p "$(docker_compose_project_name)")
    plugin_prompt_and_run "${command[@]}" "$@"
}
