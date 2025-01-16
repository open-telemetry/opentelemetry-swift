#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

HOOK_DIR=${SCRIPT_DIR}/../../.git/hooks

cp "${SCRIPT_DIR}/precommit-script.sh" "${HOOK_DIR}/precommit"

chmod 0755 "${HOOK_DIR}/precommit"