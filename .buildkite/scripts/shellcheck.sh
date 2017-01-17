#!/bin/bash

set -euo pipefail

SCRIPT=$1

shellcheck() {
    docker run \
           --volume $(pwd):/src/ \
           --workdir=/src \
           --tty \
           koalaman/shellcheck "$@"
}

shellcheck --version
shellcheck "$@"
